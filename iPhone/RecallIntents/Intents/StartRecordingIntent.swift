import AppIntents

struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static let description: IntentDescription = "Start Recall audio recording"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SharedDefaults.set(true, for: .isRecordingEnabled)
        DarwinNotification.recordingToggled.post()
        return .result(dialog: "Recording started")
    }
}
