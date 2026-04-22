import Foundation
import CoreLocation

struct LocationPoint: Codable, Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let source: String

    init(coordinate: CLLocationCoordinate2D, source: String = "ios_orion") {
        self.id        = UUID()
        self.latitude  = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = Date()
        self.source    = source
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var serverPayload: [String: Any] {
        ["latitude": latitude, "longitude": longitude,
         "timestamp": ISO8601DateFormatter().string(from: timestamp),
         "source": source]
    }

    var mapsURL: URL {
        URL(string: "https://maps.google.com/?q=\(latitude),\(longitude)")!
    }

    var formattedCoords: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }

    var timeAgoString: String {
        let secs = Int(-timestamp.timeIntervalSinceNow)
        if secs < 60  { return "только что" }
        if secs < 3600 { return "\(secs/60) мин назад" }
        return "\(secs/3600) ч назад"
    }
}
