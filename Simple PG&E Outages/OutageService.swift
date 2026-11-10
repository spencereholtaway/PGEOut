import Foundation
import CoreLocation

/// Talks to the CalOES ArcGIS feature service that publishes PG&E outage polygons.
struct OutageService {
    private static let base = URL(string: "https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services/Power_Outages_(View)/FeatureServer/1/query")!
    private static let fields = "IncidentId,OutageType,Cause,ImpactedCustomers,County,StartDate,EstimatedRestoreDate"

    /// Bounds each request so a weak signal can't keep the radio awake for long. There are no
    /// automatic retries: a failed request waits for the next scheduled check or a manual refresh.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        // Fail right away when offline rather than waiting for a connection.
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    /// Object IDs of the outages within `miles` of the coordinate, used to cheaply detect changes.
    /// Scoped to the same area as `outages(near:)`, so outages elsewhere in the state don't trigger a reload.
    func fetchIDs(near coordinate: CLLocationCoordinate2D, miles: Int = 50) async throws -> Set<Int> {
        let response: IDResponse = try await get(nearbyQuery(coordinate, miles: miles) + [
            URLQueryItem(name: "returnIdsOnly", value: "true"),
        ])
        return Set(response.objectIds ?? [])
    }

    /// Outages whose polygon contains the coordinate.
    func outages(containing coordinate: CLLocationCoordinate2D) async throws -> [Outage] {
        try await features(pointQuery(coordinate))
    }

    /// Outages within `miles` of the coordinate.
    func outages(near coordinate: CLLocationCoordinate2D, miles: Int = 50) async throws -> [Outage] {
        try await features(nearbyQuery(coordinate, miles: miles))
    }

    /// A single outage by its incident ID. Used by the debug search shortcut.
    func outage(incidentID: Int) async throws -> [Outage] {
        try await features([URLQueryItem(name: "where", value: "IncidentId=\(incidentID)")])
    }

    // MARK: - Private

    private func pointQuery(_ coordinate: CLLocationCoordinate2D) -> [URLQueryItem] {
        let geometry = #"{"x":\#(coordinate.longitude),"y":\#(coordinate.latitude),"spatialReference":{"wkid":4326}}"#
        return [
            URLQueryItem(name: "geometry", value: geometry),
            URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "inSR", value: "4326"),
        ]
    }

    private func nearbyQuery(_ coordinate: CLLocationCoordinate2D, miles: Int) -> [URLQueryItem] {
        pointQuery(coordinate) + [
            URLQueryItem(name: "distance", value: String(miles)),
            URLQueryItem(name: "units", value: "esriSRUnit_StatuteMile"),
        ]
    }

    private func features(_ query: [URLQueryItem]) async throws -> [Outage] {
        let response: FeatureResponse = try await get(query + [
            URLQueryItem(name: "outFields", value: Self.fields),
            URLQueryItem(name: "returnGeometry", value: "false"),
            URLQueryItem(name: "returnCentroid", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"),
        ])
        // The service returns every record twice, so keep the first of each incident.
        var seen = Set<String>()
        return response.features.compactMap { feature in
            let a = feature.attributes
            guard seen.insert(a.IncidentId).inserted else { return nil }
            return Outage(
                id: a.IncidentId,
                isPlanned: a.OutageType == "Planned",
                cause: a.Cause,
                impactedCustomers: a.ImpactedCustomers,
                county: a.County,
                start: a.StartDate.map { Date(timeIntervalSince1970: $0 / 1000) },
                estimatedRestore: a.EstimatedRestoreDate.map { Date(timeIntervalSince1970: $0 / 1000) },
                centroid: feature.centroid.map { CLLocationCoordinate2D(latitude: $0.y, longitude: $0.x) }
            )
        }
    }

    private func get<T: Decodable>(_ query: [URLQueryItem]) async throws -> T {
        let url = Self.base.appending(queryItems: query + [URLQueryItem(name: "f", value: "json")])
        let (data, response) = try await Self.session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Wire format

    private struct IDResponse: Decodable {
        let objectIds: [Int]?
    }

    private struct FeatureResponse: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let attributes: Attributes
        let centroid: Centroid?
    }

    private struct Attributes: Decodable {
        let IncidentId: String
        let OutageType: String?
        let Cause: String?
        let ImpactedCustomers: Int?
        let County: String?
        let StartDate: Double?
        let EstimatedRestoreDate: Double?
    }

    private struct Centroid: Decodable {
        let x: Double
        let y: Double
    }
}
