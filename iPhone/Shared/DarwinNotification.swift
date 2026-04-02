import Foundation

enum DarwinNotification: String, Sendable {
    case recordingToggled = "com.recall.recording-toggled"
    case telemetryToggled = "com.recall.telemetry-toggled"

    func post() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(rawValue as CFString), nil, nil, true)
    }

    func observe(callback: @escaping @Sendable () -> Void) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(rawValue as CFString)

        let pointer = Unmanaged.passRetained(CallbackBox(callback)).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            pointer,
            { _, pointer, _, _, _ in
                guard let pointer else { return }
                let box = Unmanaged<CallbackBox>.fromOpaque(pointer).takeUnretainedValue()
                box.callback()
            },
            rawValue as CFString,
            nil,
            .deliverImmediately
        )
    }
}

private final class CallbackBox: Sendable {
    let callback: @Sendable () -> Void
    init(_ callback: @escaping @Sendable () -> Void) {
        self.callback = callback
    }
}
