import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "LaunchSequence")

@MainActor
enum LaunchSequence {
    private(set) static var extendedRuntimeSessionManager: ExtendedRuntimeSessionManager?
    private(set) static var connectivityMonitor: ConnectivityMonitor?
    private(set) static var telemetryService: TelemetryService?
    private(set) static var locationTracker: LocationTracker?
    private(set) static var healthKitCollector: HealthKitCollector?
    private(set) static var motionActivityDetector: MotionActivityDetector?

    static func execute(
        recording: RecordingViewModel,
        upload: UploadViewModel,
        agent: AgentViewModel,
        config: ConfigViewModel
    ) async {
        logger.info("Launch sequence started")

        // 1. Start extended runtime session for background recording
        logger.info("[1/7] Starting extended runtime session")
        let sessionManager = ExtendedRuntimeSessionManager()
        sessionManager.start()
        extendedRuntimeSessionManager = sessionManager
        logger.info("[1/7] Extended runtime session started")

        // 2. Enable recording, start AudioRecordingEngine
        logger.info("[2/7] Starting audio recording engine")
        do {
            try AudioSessionManager.configure()
            recording.startRecording()
            logger.info("[2/7] Audio recording engine started")
        } catch {
            logger.error("[2/7] Failed to configure audio session: \(error.localizedDescription)")
        }

        // 3. Recover stuck uploads, retry failed
        logger.info("[3/7] Recovering uploads")
        upload.recoverStuckUploads()
        upload.retryFailed()
        logger.info("[3/7] Upload recovery complete")

        // 4. Start upload processing
        logger.info("[4/7] Starting upload processor")
        upload.startProcessing()
        logger.info("[4/7] Upload processor started")

        // 5. Start ConnectivityMonitor
        logger.info("[5/7] Starting connectivity monitor")
        let monitor = ConnectivityMonitor()
        monitor.start()
        connectivityMonitor = monitor
        logger.info("[5/7] Connectivity monitor started")

        // 6. Enable telemetry streams, start TelemetryService
        logger.info("[6/7] Starting telemetry")
        await startTelemetry(config: config)
        logger.info("[6/7] Telemetry started")

        // 7. Start WebSocket connection
        logger.info("[7/7] Starting WebSocket")
        agent.connectWebSocket()
        logger.info("[7/7] WebSocket connection initiated")

        logger.info("Launch sequence completed")
    }

    // MARK: - Step 6: Telemetry

    private static func startTelemetry(config: ConfigViewModel) async {
        let telemetry = TelemetryService()
        telemetryService = telemetry
        await telemetry.start()

        if config.isLocationEnabled {
            let tracker = LocationTracker()
            locationTracker = tracker
            await tracker.start()
        }

        if config.isHealthEnabled {
            let collector = HealthKitCollector()
            healthKitCollector = collector
            do {
                try await collector.requestAuthorization()
            } catch {
                logger.warning("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }

        if config.isMotionEnabled {
            let detector = MotionActivityDetector()
            motionActivityDetector = detector
            await detector.start(telemetry: telemetry)
        }
    }
}
