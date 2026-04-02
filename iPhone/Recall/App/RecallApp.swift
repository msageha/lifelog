import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.recall", category: "App")

@main
struct RecallApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerSetup.create()
        } catch {
            logger.fault("Failed to create ModelContainer: \(error.localizedDescription)")
            // Fallback to in-memory empty container
            do {
                modelContainer = try ModelContainer(for: Schema([]))
            } catch {
                // This should never happen with an empty schema, but handle gracefully
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
