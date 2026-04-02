import SwiftData
import SwiftUI

@main
struct RecallWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer

    init() {
        modelContainer = ModelContainerSetup.create()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
