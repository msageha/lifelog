import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.recall.watch", category: "App")

@main
struct RecallWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerSetup.create()
        } catch {
            logger.fault("Failed to create ModelContainer: \(error.localizedDescription)")
            do {
                modelContainer = try ModelContainer(for: Schema([]))
            } catch {
                logger.fault("Failed to create fallback ModelContainer: \(error.localizedDescription)")
                fatalError("Cannot create any ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
