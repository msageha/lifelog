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
            logger.fault("ModelContainer creation failed: \(error.localizedDescription). Using in-memory fallback.")
            modelContainer = try! ModelContainer(
                for: AudioChunk.self, TelemetrySample.self, HealthSnapshot.self, AgentMessage.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
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
