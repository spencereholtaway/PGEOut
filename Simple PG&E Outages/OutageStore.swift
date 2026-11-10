import Foundation
import CoreLocation

/// Holds the chosen location and the outages that affect it.
@Observable
final class OutageStore {
    enum Status: Equatable {
        case idle
        case loading
        case outages
        case none
        case outsideTerritory
        case failed
    }

    private(set) var location: SavedLocation?
    private(set) var status: Status = .idle
    /// Outages covering the location, closest first.
    private(set) var outages: [Outage] = []
    /// Up to three other outages within 50 miles, closest first.
    private(set) var nearby: [Outage] = []
    private(set) var lastChecked: Date?

    @ObservationIgnored private let service = OutageService()
    @ObservationIgnored private var knownIDs: Set<Int> = []
    /// True while showing a single outage looked up by ID, which pauses auto-refresh.
    @ObservationIgnored private var isDebugLookup = false

    private static let storageKey = "savedLocation"
    static let refreshInterval: Duration = .seconds(15 * 60)

    init(location: SavedLocation? = nil) {
        if let location {
            self.location = location
        } else if let data = UserDefaults.standard.data(forKey: Self.storageKey) {
            self.location = try? JSONDecoder().decode(SavedLocation.self, from: data)
        }
    }

    /// Switches to a new location and loads its outages.
    func select(_ newLocation: SavedLocation) async {
        isDebugLookup = false
        location = newLocation
        if let data = try? JSONEncoder().encode(newLocation) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        outages = []
        nearby = []
        await load()
    }

    /// Reloads outages for the current location.
    func load() async {
        guard let location, !isDebugLookup else { return }
        guard location.isInServiceTerritory else {
            outages = []
            nearby = []
            status = .outsideTerritory
            return
        }
        if outages.isEmpty && nearby.isEmpty { status = .loading }

        let coordinate = location.coordinate
        do {
            let covering = try await service.outages(containing: coordinate)
            outages = sortedByDistance(covering, from: coordinate)
            status = covering.isEmpty ? .none : .outages

            // Nearby outages are a bonus, so a failure here doesn't fail the screen.
            let coveringIDs = Set(covering.map(\.id))
            if let around = try? await service.outages(near: coordinate) {
                nearby = Array(sortedByDistance(around.filter { !coveringIDs.contains($0.id) }, from: coordinate).prefix(3))
            }
        } catch {
            status = .failed
        }
        lastChecked = .now
    }

    /// Reloads only if the set of outages has changed since the last check.
    func refreshIfChanged() async {
        guard let ids = try? await service.fetchIDs() else { return }
        if ids != knownIDs {
            knownIDs = ids
            await load()
        }
        lastChecked = .now
    }

    /// Debug shortcut: show a single outage by incident ID.
    func lookUp(incidentID: Int) async {
        isDebugLookup = true
        location = nil
        nearby = []
        status = .loading
        do {
            outages = try await service.outage(incidentID: incidentID)
            status = outages.isEmpty ? .none : .outages
        } catch {
            status = .failed
        }
        lastChecked = .now
    }

    private func sortedByDistance(_ list: [Outage], from coordinate: CLLocationCoordinate2D) -> [Outage] {
        list.sorted {
            ($0.distance(from: coordinate)?.value ?? .infinity) < ($1.distance(from: coordinate)?.value ?? .infinity)
        }
    }
}

extension OutageStore {
    /// A store pre-filled with sample data for previews.
    static func preview(status: Status = .outages) -> OutageStore {
        let home = SavedLocation(
            latitude: 37.7749, longitude: -122.4194,
            title: "1 Dr Carlton B Goodlett Pl", subtitle: "San Francisco, CA",
            state: "CA", county: "San Francisco"
        )
        let store = OutageStore(location: home)
        store.status = status
        store.lastChecked = .now
        if status == .outages {
            store.outages = [.sample(id: "1", planned: false, cause: "TREE CONTACT", near: home.coordinate, offset: 0)]
        }
        if status == .outages || status == .none {
            store.nearby = [
                .sample(id: "2", planned: true, cause: "PLNND SHUTDOWN", near: home.coordinate, offset: 0.004),
                .sample(id: "3", planned: false, cause: "PATROLLING", near: home.coordinate, offset: 0.06),
                .sample(id: "4", planned: false, cause: nil, near: home.coordinate, offset: 0.2),
            ]
        }
        return store
    }
}

extension Outage {
    static func sample(id: String, planned: Bool, cause: String?, near coordinate: CLLocationCoordinate2D, offset: Double) -> Outage {
        Outage(
            id: id,
            isPlanned: planned,
            cause: cause,
            impactedCustomers: 120,
            county: "SAN FRANCISCO",
            start: .now.addingTimeInterval(-2 * 3600),
            estimatedRestore: .now.addingTimeInterval(planned ? 6 * 3600 : 1.5 * 3600),
            centroid: CLLocationCoordinate2D(latitude: coordinate.latitude + offset, longitude: coordinate.longitude)
        )
    }
}
