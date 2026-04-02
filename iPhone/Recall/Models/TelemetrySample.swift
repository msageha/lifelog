import Foundation
import SwiftData

@Model
final class TelemetrySample {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var horizontalAccuracy: Double
    var speed: Double
    var motionActivity: String
    var motionConfidence: String
    var timestamp: Date
    var isSent: Bool

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        speed: Double,
        motionActivity: String = "unknown",
        motionConfidence: String = "low",
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.motionActivity = motionActivity
        self.motionConfidence = motionConfidence
        self.timestamp = timestamp
        self.isSent = false
    }
}
