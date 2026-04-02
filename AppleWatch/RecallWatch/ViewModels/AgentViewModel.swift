import Foundation

@Observable
@MainActor
final class AgentViewModel {
    var messages: [AgentMessage] = []
    var isWebSocketConnected: Bool = false
    var volume: Float = 1.0

    func connectWebSocket() {
        // TODO: Connect WebSocketClient
    }

    func disconnectWebSocket() {
        // TODO: Disconnect WebSocketClient
    }
}
