import Foundation
import SwiftData

enum ModelContainerSetup {
    static func create() throws -> ModelContainer {
        let schema = Schema([
            AudioChunk.self,
            TelemetrySample.self,
            HealthSnapshot.self,
            AgentMessage.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
