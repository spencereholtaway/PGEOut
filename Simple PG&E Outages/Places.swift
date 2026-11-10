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

        var errorDescription: String? {
            switch self {
            case .denied: String(localized: "Location access is off. Allow it in Settings, or search for an address instead.")
            case .notFound: String(localized: "That address couldn’t be found.")
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
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }

        var found: CLLocation?
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location {
                found = location
                break
            }
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                throw LocationError.denied
            }
        }
        guard let found else { throw LocationError.notFound }

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

    private static func savedLocation(from item: MKMapItem, title: String) -> SavedLocation {
        let coordinate = item.location.coordinate
        // MKAddressRepresentations doesn't expose state or county, which the
        // service-territory check needs, so read them from the placemark.
        let placemark = item.placemark
        return SavedLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            title: title,
            subtitle: item.addressRepresentations?.cityWithContext(.short),
            state: placemark.administrativeArea,
            county: placemark.subAdministrativeArea
        )
    }
}
