import ActivityKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "LaunchSequence")

@MainActor
enum LaunchSequence {
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

        // 1. Enable recording, start AudioRecordingEngine
        logger.info("[1/8] Starting audio recording engine")
        do {
            try AudioSessionManager.configure()
            recording.startRecording()
            logger.info("[1/8] Audio recording engine started")
        } catch {
            logger.error("[1/8] Failed to configure audio session: \(error.localizedDescription)")
        }

        // 2. Start Live Activity
        logger.info("[2/8] Starting Live Activity")
        startLiveActivity(recording: recording)

        // 3. Recover stuck uploads, retry failed
        logger.info("[3/8] Recovering uploads")
        upload.recoverStuckUploads()
        upload.retryFailed()
        logger.info("[3/8] Upload recovery complete")

        // 4. Start upload processing
        logger.info("[4/8] Starting upload processor")
        upload.startProcessing()
        logger.info("[4/8] Upload processor started")

        // 5. Start ConnectivityMonitor
        logger.info("[5/8] Starting connectivity monitor")
        let monitor = ConnectivityMonitor()
        monitor.start()
        connectivityMonitor = monitor
        logger.info("[5/8] Connectivity monitor started")

        // 6. Enable telemetry streams, start TelemetryService
        logger.info("[6/8] Starting telemetry")
        await startTelemetry(config: config)
        logger.info("[6/8] Telemetry started")

        // 7. Start WebSocket connection
        logger.info("[7/8] Starting WebSocket")
        agent.connectWebSocket()
        logger.info("[7/8] WebSocket connection initiated")

        // 8. Observe Control Center widget toggle
        logger.info("[8/8] Observing Control Center toggle")
        observeControlCenterToggle(recording: recording)
        logger.info("[8/8] Control Center observation active")

        logger.info("Launch sequence completed")
    }

    // MARK: - Step 2: Live Activity

    private static func startLiveActivity(recording: RecordingViewModel) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities not enabled")
            return
        }

        let attributes = RecallActivityAttributes()
        let initialState = RecallActivityAttributes.ContentState(
            isRecording: recording.state == .recording,
            elapsedSeconds: recording.elapsedSeconds,
            chunkCount: recording.totalChunksRecorded,
            vadProbability: recording.vadProbability
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            logger.info("Live Activity started")
        } catch {
            logger.warning("Failed to start Live Activity: \(error.localizedDescription)")
        }
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
            await detector.start()
        }
    }

    // MARK: - Step 8: Control Center Toggle

    private static func observeControlCenterToggle(recording: RecordingViewModel) {
        DarwinNotification.recordingToggled.observe {
            let isEnabled = SharedDefaults.bool(for: .isRecordingEnabled)
            Task { @MainActor in
                if isEnabled {
                    recording.startRecording()
                    logger.info("Recording enabled via Control Center")
                } else {
                    recording.stopRecording()
                    logger.info("Recording disabled via Control Center")
                }
            }
        }
    }
}
