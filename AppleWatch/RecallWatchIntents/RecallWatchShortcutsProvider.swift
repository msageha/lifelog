import AppIntents

struct RecallWatchShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording with \(.applicationName)",
                "\(.applicationName)で録音を開始して",
            ],
            shortTitle: "Start Recording",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop recording with \(.applicationName)",
                "\(.applicationName)で録音を停止して",
            ],
            shortTitle: "Stop Recording",
            systemImageName: "mic.slash.fill"
        )
        AppShortcut(
            intent: RecordingStatusIntent(),
            phrases: [
                "What is \(.applicationName) recording status",
                "\(.applicationName)の録音状態は",
            ],
            shortTitle: "Recording Status",
            systemImageName: "info.circle"
        )
    }
}
