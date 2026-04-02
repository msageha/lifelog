import AppIntents

struct UploadStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Upload Status"
    static let description: IntentDescription = "Check Recall upload status"
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pending = SharedDefaults.integer(for: .pendingChunkCount)
        let uploaded = SharedDefaults.integer(for: .uploadedChunkCount)
        let lastUpload = SharedDefaults.date(for: .lastUploadDate)

        let lastUploadText: String
        if let lastUpload {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lastUploadText = formatter.localizedString(for: lastUpload, relativeTo: Date())
        } else {
            lastUploadText = "never"
        }

        let dialog: String
        if pending == 0 && uploaded == 0 {
            dialog = "No upload activity yet."
        } else {
            dialog = "Uploaded: \(uploaded) chunks. Pending: \(pending) chunks. Last upload: \(lastUploadText)."
        }

        return .result(dialog: "\(dialog)")
    }
}
