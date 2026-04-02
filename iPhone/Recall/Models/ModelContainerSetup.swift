import Foundation
import SwiftData

enum ModelContainerError: Error {
    case creationFailed(underlying: Error)
}

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

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            throw ModelContainerError.creationFailed(underlying: error)
        }
    }
}
