import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    var id: UUID
    var steps: Int
    var activeEnergyKcal: Double
    var walkingDistanceMeters: Double
    var averageHeartRate: Double?
    var totalSleepMinutes: Double?
    var remSleepMinutes: Double?
    var deepSleepMinutes: Double?
    var coreSleepMinutes: Double?
    var timestamp: Date
    var isSent: Bool

    init(
        steps: Int = 0,
        activeEnergyKcal: Double = 0,
        walkingDistanceMeters: Double = 0,
        averageHeartRate: Double? = nil,
        totalSleepMinutes: Double? = nil,
        remSleepMinutes: Double? = nil,
        deepSleepMinutes: Double? = nil,
        coreSleepMinutes: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.walkingDistanceMeters = walkingDistanceMeters
        self.averageHeartRate = averageHeartRate
        self.totalSleepMinutes = totalSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.coreSleepMinutes = coreSleepMinutes
        self.timestamp = timestamp
        self.isSent = false
    }
}
