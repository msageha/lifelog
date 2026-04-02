import AppIntents

struct UploadStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Upload Status"
    static let description: IntentDescription = "Check Recall upload status"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // TODO: Read actual counts from shared state
        return .result(dialog: "Upload status check is not yet implemented")
    }
}
