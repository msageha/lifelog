import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "AgentVM")

@Observable
@MainActor
final class AgentViewModel {
    var messages: [AgentMessage] = []
    var isWebSocketConnected: Bool = false
    var volume: Float = 1.0

    private let webSocketClient: WebSocketClient
    private let messageReceiver: AgentMessageReceiver

    init(
        webSocketClient: WebSocketClient,
        messageReceiver: AgentMessageReceiver
    ) {
        self.webSocketClient = webSocketClient
        self.messageReceiver = messageReceiver
    }

    func connectWebSocket() {
        guard let urlString = SharedDefaults.string(for: .webSocketServerURL),
              let url = URL(string: urlString) else {
            logger.error("No WebSocket server URL configured")
            return
        }
        guard let token = KeychainHelper.load(key: "bearerToken"),
              !token.isEmpty else {
            logger.error("No bearer token available")
            return
        }

        Task {
            await webSocketClient.connect(url: url, token: token)
            isWebSocketConnected = true
            logger.info("WebSocket connected")
        }
    }

    func disconnectWebSocket() {
        Task {
            await webSocketClient.disconnect()
            isWebSocketConnected = false
            logger.info("WebSocket disconnected")
        }
    }
}
