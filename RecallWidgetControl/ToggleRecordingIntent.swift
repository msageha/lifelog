import AppIntents

struct ToggleRecordingIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Recording"
    static let description: IntentDescription = "Toggles Recall audio recording on or off"

    @Parameter(title: "Recording")
    var value: Bool

    func perform() async throws -> some IntentResult {
        SharedDefaults.set(value, for: .isRecordingEnabled)
        DarwinNotification.recordingToggled.post()
        return .result()
    }
}
