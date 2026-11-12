import Foundation
import MapKit

/// Live address suggestions from MapKit, scoped to California.
@Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // California's bounding box; results outside it are dropped.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.27, longitude: -119.30),
            span: MKCoordinateSpan(latitudeDelta: 9.5, longitudeDelta: 10.4)
        )
        completer.regionPriority = .required
    }

    var query: String = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                completer.cancel()
                results = []
            } else {
                completer.queryFragment = trimmed
            }
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        results = []
    }
}

enum Places {
    enum LocationError: LocalizedError {
        case denied
        case notFound
        case unavailable

        var errorDescription: String? {
            switch self {
            case .denied: String(localized: "Location access is off. Allow it in Settings, or search for an address instead.")
            case .notFound: String(localized: "That address couldn’t be found.")
            case .unavailable: String(localized: "Your location couldn’t be found right now. Try again, or search for an address instead.")
            }
        }
    }

    /// Turns an autocomplete suggestion into a coordinate with state and county.
    static func resolve(_ completion: MKLocalSearchCompletion) async throws -> SavedLocation {
        let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
        guard let item = response.mapItems.first else { throw LocationError.notFound }
        return savedLocation(from: item, title: completion.title)
    }

    /// Finds the device's location once, then reverse geocodes it.
    static func currentLocation() async throws -> SavedLocation {
        let found = try await locationFix()

        guard let request = MKReverseGeocodingRequest(location: found),
              let item = try await request.mapItems.first else {
            return SavedLocation(
                latitude: found.coordinate.latitude,
                longitude: found.coordinate.longitude,
                title: String(localized: "Current Location"),
                state: nil
            )
        }
        var saved = savedLocation(from: item, title: item.address?.shortAddress ?? String(localized: "Current Location"))
        // Keep the precise device coordinate rather than the geocoded address point.
        saved.latitude = found.coordinate.latitude
        saved.longitude = found.coordinate.longitude
        return saved
    }

    /// A short street-and-city description of a coordinate, such as "Van Ness, San Francisco".
    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        return item.address?.shortAddress ?? item.addressRepresentations?.cityWithContext(.short)
    }

    /// Drops a leading house number, turning "1528 Leavenworth St, San Francisco"
    /// into "Leavenworth St, San Francisco".
    static func streetAndCity(_ address: String) -> String {
        address.replacing(/^\d[\d\-]*[A-Za-z]?\s+/, with: "")
    }

    /// A fix this accurate is plenty to find the outage polygon covering it.
    private static let acceptableAccuracy: CLLocationAccuracy = 100

    /// Gets one location fix, keeping location hardware on no longer than needed:
    /// it takes the first recent fix within 100 m, settles for the latest fix after 10 seconds
    /// of searching, and gives up entirely after 30 seconds in case no fix arrives at all.
    private static func locationFix() async throws -> CLLocation {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }

        let fix = try await withThrowingTaskGroup(of: CLLocation?.self, returning: CLLocation?.self) { group in
            group.addTask { try await Places.followUpdates(settlingAfter: .seconds(10)) }
            group.addTask {
                try? await Task.sleep(for: .seconds(30))
                return nil
            }
            defer { group.cancelAll() }
            for try await result in group {
                if let result { return result }
                // Time's up: cancelling stops location updates and returns the latest fix, if any.
                group.cancelAll()
            }
            return nil
        }
        guard let fix else { throw LocationError.unavailable }
        return fix
    }

    /// Follows location updates until one is good enough, then returns, which stops the updates.
    private static func followUpdates(settlingAfter settleTime: Duration) async throws -> CLLocation? {
        var latest: CLLocation?
        var searchStart: ContinuousClock.Instant?
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                throw LocationError.denied
            }
            // Location hardware stays off while the permission prompt is up, so start the settle clock after it.
            if update.authorizationRequestInProgress { continue }
            if searchStart == nil { searchStart = ContinuousClock.now }

            if let location = update.location, location.horizontalAccuracy >= 0 {
                latest = location
                if location.horizontalAccuracy <= acceptableAccuracy && location.timestamp.timeIntervalSinceNow > -60 {
                    return location
                }
            }
            // Accuracy won't improve while the device sits still, and a rough fix beats searching longer.
            if let latest, let searchStart, update.stationary || searchStart.duration(to: ContinuousClock.now) >= settleTime {
                return latest
            }
        }
        // Updates end when the task is cancelled by the timeout.
        return latest
    }

    private static func savedLocation(from item: MKMapItem, title: String) -> SavedLocation {
        let coordinate = item.location.coordinate
        // MKAddressRepresentations doesn't expose state or county, which the
        // service-territory check needs, so read them from the placemark.
        let placemark = item.placemark
        // Reverse-geocoded titles like "Van Ness, San Francisco" already include the city,
        // so skip the city line rather than repeat it.
        let city = item.addressRepresentations?.cityName
        let titleHasCity = city.map { title.localizedStandardContains($0) } ?? false
        return SavedLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            title: title,
            subtitle: titleHasCity ? nil : item.addressRepresentations?.cityWithContext(.short),
            state: placemark.administrativeArea,
            county: placemark.subAdministrativeArea
        )
    }
}
