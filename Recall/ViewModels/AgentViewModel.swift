import Foundation

@Observable
@MainActor
final class AgentViewModel {
    var messages: [AgentMessage] = []
    var isWebSocketConnected: Bool = false
    var spatialAzimuth: Float = 0.0
    var spatialDistance: Float = 1.0
    var spatialVolume: Float = 1.0

    func connectWebSocket() {
        // TODO: Connect WebSocketClient
    }

    func disconnectWebSocket() {
        // TODO: Disconnect WebSocketClient
    }

    func updateSpatialSettings() {
        // TODO: Update SpatialAudioPlayer parameters
    }
}
