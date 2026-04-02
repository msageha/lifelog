import AppIntents

struct RecordingStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Recording Status"
    static let description: IntentDescription = "Check Recall recording status"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = SharedDefaults.recordingState
        let message: String
        switch state {
        case .idle:
            message = "Recording is stopped"
        case .listening:
            message = "Listening for speech"
        case .recording:
            message = "Currently recording"
        }
        return .result(dialog: "\(message)")
    }
}
