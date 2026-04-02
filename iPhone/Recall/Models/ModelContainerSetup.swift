import Foundation
import SwiftData

enum ModelContainerSetup {
    enum SetupError: Error, LocalizedError {
        case containerCreationFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .containerCreationFailed(let underlying):
                return "Failed to create ModelContainer: \(underlying.localizedDescription)"
            }
        }
    }

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
            throw SetupError.containerCreationFailed(underlying: error)
        }
    }
}
