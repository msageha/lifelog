import AppIntents

struct StopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description: IntentDescription = "Stop Recall audio recording"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SharedDefaults.set(false, for: .isRecordingEnabled)
        DarwinNotification.recordingToggled.post()
        return .result(dialog: "Recording stopped")
    }
}
