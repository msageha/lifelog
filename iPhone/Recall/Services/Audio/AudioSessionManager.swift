import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "AudioSession")

enum AudioSessionManager {
    /// Callback invoked on interruption begin/end. `true` = began, `false` = ended.
    static var onInterruption: ((Bool) -> Void)?
    /// Callback invoked when audio route changes (e.g. headphone/Bluetooth disconnect).
    static var onRouteChange: ((AVAudioSession.RouteChangeReason) -> Void)?

    static func configure() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setPreferredSampleRate(Constants.Audio.sampleRate)
        try session.setActive(true)

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { notification in
            handleInterruption(notification)
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { notification in
            handleRouteChange(notification)
        }

        logger.info("Audio session configured")
    }

    static func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private static func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            logger.info("Audio interruption began")
            onInterruption?(true)
        case .ended:
            logger.info("Audio interruption ended")
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    logger.info("Interruption ended with shouldResume flag")
                    onInterruption?(false)
                }
            } else {
                onInterruption?(false)
            }
        @unknown default:
            break
        }
    }

    private static func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        logger.info("Audio route changed: \(reason.rawValue)")
        onRouteChange?(reason)

        switch reason {
        case .oldDeviceUnavailable:
            logger.info("Audio device disconnected (headphones/Bluetooth removed)")
        case .newDeviceAvailable:
            logger.info("New audio device connected")
        default:
            break
        }
    }
}
