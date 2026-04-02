import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "Telemetry")

actor TelemetryService {
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        logger.info("Telemetry service started")
        // TODO: Start periodic batch send of location + health data
    }

    func stop() {
        isRunning = false
        logger.info("Telemetry service stopped")
    }

    func sendBatch(samples: [LocationSampleDTO], health: HealthSnapshotDTO?) async throws {
        // TODO: POST /api/telemetry with Bearer auth
        logger.info("Telemetry batch sent: \(samples.count) samples")
    }
}
