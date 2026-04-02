import AppIntents

struct ToggleTelemetryIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Telemetry"
    static let description: IntentDescription = "Toggle Recall location telemetry"
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Enabled")
    var enabled: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SharedDefaults.set(enabled, for: .isLocationEnabled)
        DarwinNotification.telemetryToggled.post()
        let status = enabled ? "enabled" : "disabled"
        return .result(dialog: "Location telemetry \(status)")
    }
}
