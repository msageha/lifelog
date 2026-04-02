import Foundation
import HealthKit
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "HealthBGDelivery")

actor HealthBackgroundDelivery {
    private let store = HKHealthStore()

    func enable() {
        let types: [(HKQuantityType, HKUpdateFrequency)] = [
            (HKQuantityType(.stepCount), .immediate),
            (HKQuantityType(.heartRate), .immediate),
        ]

        for (type, frequency) in types {
            store.enableBackgroundDelivery(for: type, frequency: frequency) { success, error in
                if let error {
                    logger.error("Failed to enable BG delivery for \(type.identifier): \(error)")
                } else if success {
                    logger.info("BG delivery enabled for \(type.identifier)")
                }
            }
        }
    }
}
