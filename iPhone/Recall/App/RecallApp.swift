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
            // Fallback to in-memory container with full schema
            do {
                let schema = Schema([
                    AudioChunk.self,
                    TelemetrySample.self,
                    HealthSnapshot.self,
                    AgentMessage.self,
                ])
                let config = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
                modelContainer = try ModelContainer(for: schema, configurations: [config])
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
