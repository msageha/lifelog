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
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        async let steps = queryCumulativeSum(.stepCount, unit: .count(), predicate: predicate)
        async let energy = queryCumulativeSum(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        async let distance = queryCumulativeSum(.distanceWalkingRunning, unit: .meter(), predicate: predicate)
        async let heartRate = queryLatestSample(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let sleep = querySleepAnalysis()

        let (stepsVal, energyVal, distanceVal, hrVal, sleepResult) = try await (steps, energy, distance, heartRate, sleep)

        let snapshot = HealthSnapshotDTO(
            steps: Int(stepsVal),
            activeEnergyKcal: energyVal,
            walkingDistanceMeters: distanceVal,
            averageHeartRate: hrVal,
            totalSleepMinutes: sleepResult.total,
            remSleepMinutes: sleepResult.rem,
            deepSleepMinutes: sleepResult.deep,
            coreSleepMinutes: sleepResult.core
        )

        logger.info("Health snapshot collected: \(snapshot.steps) steps, \(snapshot.activeEnergyKcal) kcal")
        return snapshot
    }

    // MARK: - Cumulative Statistics Query

    private func queryCumulativeSum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double {
        let quantityType = HKQuantityType(identifier)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    // MARK: - Latest Sample Query

    private func queryLatestSample(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        let quantityType = HKQuantityType(identifier)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep Analysis Query

    private struct SleepResult {
        var total: Double?
        var rem: Double?
        var deep: Double?
        var core: Double?
    }

    private func querySleepAnalysis() async throws -> SleepResult {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let calendar = Calendar.current
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var result = SleepResult()
                var totalMinutes: Double = 0
                var remMinutes: Double = 0
                var deepMinutes: Double = 0
                var coreMinutes: Double = 0

                for sample in (samples as? [HKCategorySample]) ?? [] {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }

                    switch value {
                    case .asleepREM:
                        remMinutes += duration
                        totalMinutes += duration
                    case .asleepDeep:
                        deepMinutes += duration
                        totalMinutes += duration
                    case .asleepCore:
                        coreMinutes += duration
                        totalMinutes += duration
                    case .asleepUnspecified, .asleep:
                        totalMinutes += duration
                    case .inBed, .awake:
                        break
                    @unknown default:
                        break
                    }
                }

                if totalMinutes > 0 {
                    result.total = totalMinutes
                    result.rem = remMinutes > 0 ? remMinutes : nil
                    result.deep = deepMinutes > 0 ? deepMinutes : nil
                    result.core = coreMinutes > 0 ? coreMinutes : nil
                }

                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }
}

struct HealthSnapshotDTO: Codable, Sendable {
    var steps: Int = 0
    var activeEnergyKcal: Double = 0
    var walkingDistanceMeters: Double = 0
    var averageHeartRate: Double?
    var totalSleepMinutes: Double?
    var remSleepMinutes: Double?
    var deepSleepMinutes: Double?
    var coreSleepMinutes: Double?
}
