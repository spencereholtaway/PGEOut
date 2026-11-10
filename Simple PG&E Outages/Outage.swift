import Foundation
import CoreLocation

/// A single outage reported by the CalOES power outage feed.
struct Outage: Identifiable, Hashable {
    let id: String
    let isPlanned: Bool
    let cause: String?
    let impactedCustomers: Int?
    let county: String?
    let start: Date?
    let estimatedRestore: Date?
    let centroid: CLLocationCoordinate2D?

    /// A human-readable description of the utility's cause code.
    var causeDescription: String {
        guard let cause else { return String(localized: "Outage cause currently unknown") }
        return Self.causeLabels[cause] ?? cause
    }

    /// How far through the start → estimated restore window we are, from 0 to 1.
    func progress(at now: Date) -> Double {
        guard let start, let estimatedRestore else { return 0 }
        let total = estimatedRestore.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    /// Distance from a coordinate to the outage's centroid.
    func distance(from coordinate: CLLocationCoordinate2D) -> Measurement<UnitLength>? {
        guard let centroid else { return nil }
        let meters = CLLocation(latitude: centroid.latitude, longitude: centroid.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        return Measurement(value: meters, unit: .meters)
    }

    static func == (lhs: Outage, rhs: Outage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private static let causeLabels: [String: String] = [
        "EMERG REPAIRS": "Emergency repairs underway",
        "TREE CONTACT": "Tree contact with power line",
        "PATROLLING": "Crew is patrolling to locate the fault",
        "PLNND SHUTDOWN": "Planned shutdown",
        "DAMGE UG CABLE": "Damaged underground cable",
        "REPLCE TXFMR": "Replacing transformer",
        "REPLCE SRVC": "Replacing service line",
        "BRKN UG EQUIPMNT": "Broken underground equipment",
        "BRKN POLE EQUIPMNT": "Broken pole equipment",
        "BRKN POLE": "Broken pole",
        "POLE FIRE": "Pole fire",
        "CAR POLE": "Vehicle struck a power pole",
        "FOREIGN OBJ": "Foreign object contact",
        "NG CONNECTION": "Faulty connection",
        "THRD PARTY": "Third party damage",
        "WM - VEG Removal": "Vegetation removal",
        "Awaiting Investigation": "Awaiting investigation",
    ]
}

/// A location the person searched for or their current position.
struct SavedLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// First line, such as the street address.
    var title: String
    /// Second line, such as "San Francisco, CA".
    var subtitle: String?
    /// Two-letter state code or full state name, if known.
    var state: String?
    var county: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Southern California counties served by other utilities.
    private static let nonPGECounties: Set<String> = [
        "LOS ANGELES", "SAN DIEGO", "ORANGE", "RIVERSIDE",
        "SAN BERNARDINO", "IMPERIAL", "VENTURA",
    ]

    /// Whether the location falls within PG&E's service territory.
    var isInServiceTerritory: Bool {
        guard let state = state?.uppercased(), state == "CA" || state == "CALIFORNIA" else { return false }
        // Assume PG&E when the county is unknown.
        guard let county else { return true }
        let normalized = county.uppercased().replacing(" COUNTY", with: "").trimmingCharacters(in: .whitespaces)
        return !Self.nonPGECounties.contains(normalized)
    }
}
