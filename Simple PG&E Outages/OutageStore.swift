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
    /// Street-and-city descriptions of nearby outages, looked up once per outage.
    private(set) var placeNames: [Outage.ID: String] = [:]
    @ObservationIgnored private var placeLookups: Set<Outage.ID> = []

    @ObservationIgnored private let service = OutageService()
    @ObservationIgnored private var knownIDs: Set<Int> = []
    /// When data was last requested, whether or not it arrived. Limits how often refreshes run.
    @ObservationIgnored private var lastAttempt: ContinuousClock.Instant?
    /// True while showing a single outage looked up by ID, which pauses auto-refresh.
    @ObservationIgnored private var isDebugLookup = false
    /// True for preview stores, which show sample data instead of fetching.
    @ObservationIgnored private var isPreview = false

    private static let storageKey = "savedLocation"
    static let refreshInterval: Duration = .seconds(15 * 60)

    init(location: SavedLocation? = nil) {
        if let location {
            self.location = location
        } else if let data = UserDefaults.standard.data(forKey: Self.storageKey) {
            self.location = try? JSONDecoder().decode(SavedLocation.self, from: data)
        }
    }

    /// Looks up where an outage is, at most once per outage, so refreshes don't repeat the request.
    func lookUpPlaceName(for outage: Outage) async {
        guard !isPreview, let centroid = outage.centroid,
              placeLookups.insert(outage.id).inserted else { return }
        if let name = await Places.placeName(for: centroid) {
            placeNames[outage.id] = name
        } else {
            // Allow another try next time the row appears.
            placeLookups.remove(outage.id)
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
        knownIDs = []
        status = .loading
        await load()
    }

    /// Reloads outages for the current location.
    func load() async {
        guard let location, !isDebugLookup, !isPreview else { return }
        guard location.isInServiceTerritory else {
            outages = []
            nearby = []
            status = .outsideTerritory
            return
        }
        let showingResults = status == .outages || status == .none
        if !showingResults { status = .loading }
        lastAttempt = ContinuousClock.now

        let coordinate = location.coordinate
        let service = self.service
        // Send every request at once so the radio wakes once and can go back to sleep sooner.
        async let coveringRequest = service.outages(containing: coordinate)
        async let nearbyRequest = service.outages(near: coordinate)
        async let idsRequest = service.fetchIDs(near: coordinate)
        do {
            let covering = try await coveringRequest
            outages = sortedByDistance(covering, from: coordinate)
            status = covering.isEmpty ? .none : .outages
            lastChecked = .now

            // Nearby outages are a bonus, so a failure here doesn't fail the screen.
            let coveringIDs = Set(covering.map(\.id))
            if let around = try? await nearbyRequest {
                nearby = Array(sortedByDistance(around.filter { !coveringIDs.contains($0.id) }, from: coordinate).prefix(3))
            }
            // Remember what was loaded so the periodic check can skip a reload when nothing changed.
            if let ids = try? await idsRequest {
                knownIDs = ids
            }
        } catch {
            if Task.isCancelled {
                // The app left the foreground mid-request. Let the next foreground refresh try again.
                lastAttempt = nil
            } else if !showingResults {
                // Earlier results stay on screen if there are any. Either way, the next try is the
                // next scheduled check or a manual refresh, never an immediate retry.
                status = .failed
            }
        }
    }

    /// Reloads only if the set of nearby outages has changed since the last load.
    func refreshIfChanged() async {
        guard let location, location.isInServiceTerritory, !isDebugLookup, !isPreview else { return }
        lastAttempt = ContinuousClock.now
        do {
            let ids = try await service.fetchIDs(near: location.coordinate)
            if ids != knownIDs {
                await load()
            } else {
                lastChecked = .now
            }
        } catch {
            if Task.isCancelled { lastAttempt = nil }
        }
    }

    /// Brings data up to date when the app returns to the foreground, unless it was checked recently.
    func refreshIfStale() async {
        if let lastAttempt, lastAttempt.duration(to: ContinuousClock.now) < Self.refreshInterval { return }
        if status == .outages || status == .none {
            await refreshIfChanged()
        } else {
            await load()
        }
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
        store.isPreview = true
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
            store.placeNames = ["2": "Van Ness Ave, San Francisco", "3": "Lombard St, San Francisco", "4": "Bridgeway, Sausalito"]
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
