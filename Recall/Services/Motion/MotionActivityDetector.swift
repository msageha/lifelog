import CoreMotion
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "MotionActivity")

actor MotionActivityDetector {
    private let manager = CMMotionActivityManager()
    private(set) var currentActivity: DetectedActivity = .unknown
    private(set) var confidence: CMMotionActivityConfidence = .low

    func start() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            logger.warning("Motion activity not available")
            return
        }

        manager.startActivityUpdates(to: .main) { activity in
            guard let activity else { return }
            let walking = activity.walking
            let running = activity.running
            let automotive = activity.automotive
            let cycling = activity.cycling
            let stationary = activity.stationary
            let conf = activity.confidence
            Task { [weak self] in
                await self?.updateState(
                    walking: walking, running: running, automotive: automotive,
                    cycling: cycling, stationary: stationary, confidence: conf
                )
            }
        }
        logger.info("Motion activity detection started")
    }

    func stop() {
        manager.stopActivityUpdates()
        logger.info("Motion activity detection stopped")
    }

    private func updateState(
        walking: Bool, running: Bool, automotive: Bool,
        cycling: Bool, stationary: Bool, confidence: CMMotionActivityConfidence
    ) {
        self.confidence = confidence
        if walking { currentActivity = .walking }
        else if running { currentActivity = .running }
        else if automotive { currentActivity = .automotive }
        else if cycling { currentActivity = .cycling }
        else if stationary { currentActivity = .stationary }
        else { currentActivity = .unknown }
    }
}

enum DetectedActivity: String, Codable, Sendable {
    case walking, running, automotive, cycling, stationary, unknown
}
