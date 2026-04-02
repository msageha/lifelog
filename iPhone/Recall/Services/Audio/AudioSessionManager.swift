import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "AudioSession")

enum AudioSessionManager {
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
            NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
        case .ended:
            logger.info("Audio interruption ended")
            let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
                .map { $0.contains(.shouldResume) } ?? false
            NotificationCenter.default.post(
                name: .audioInterruptionEnded,
                object: nil,
                userInfo: ["shouldResume": shouldResume]
            )
        @unknown default:
            break
        }
    }

    private static func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        let outputs = currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", ")
        logger.info("Audio route changed: reason=\(reason.rawValue) outputs=[\(outputs)]")

        if reason == .oldDeviceUnavailable {
            NotificationCenter.default.post(name: .audioRouteDeviceLost, object: nil)
        }
    }
}

extension Notification.Name {
    static let audioInterruptionBegan = Notification.Name("audioInterruptionBegan")
    static let audioInterruptionEnded = Notification.Name("audioInterruptionEnded")
    static let audioRouteDeviceLost = Notification.Name("audioRouteDeviceLost")
}
