import Foundation
import HealthKit
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "HealthKit")

actor HealthKitCollector {
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType(),
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
        logger.info("HealthKit authorization requested")
    }

    func collectSnapshot() async throws -> HealthSnapshotDTO {
        // TODO: Query steps, energy, distance, HR, sleep, workouts
        logger.info("Health snapshot collected")
        return HealthSnapshotDTO()
    }
}

struct HealthSnapshotDTO: Sendable {
    var steps: Int = 0
    var activeEnergyKcal: Double = 0
    var walkingDistanceMeters: Double = 0
    var averageHeartRate: Double?
    var totalSleepMinutes: Double?
    var remSleepMinutes: Double?
    var deepSleepMinutes: Double?
    var coreSleepMinutes: Double?
}
