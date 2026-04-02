import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "AudioSession")

enum AudioSessionManager {
    private static var interruptionObserver: (any NSObjectProtocol)?
    private static var routeChangeObserver: (any NSObjectProtocol)?

    static func configure() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setPreferredSampleRate(Constants.Audio.sampleRate)
        try session.setActive(true)

        // Remove previous observers to prevent duplicates
        if let token = interruptionObserver {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = routeChangeObserver {
            NotificationCenter.default.removeObserver(token)
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { notification in
            handleInterruption(notification)
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { notification in
            handleRouteChange(notification)
        }

        logger.info("Audio session configured for watchOS")
    }

    private static func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            logger.info("Audio interruption began")
            // TODO: Pause recording
        case .ended:
            logger.info("Audio interruption ended")
            // TODO: Resume recording
        @unknown default:
            break
        }
    }

    private static func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        logger.info("Audio route changed: \(reason.rawValue)")
    }
}
