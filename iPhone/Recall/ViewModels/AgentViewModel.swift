import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "AgentVM")

@Observable
@MainActor
final class AgentViewModel {
    var messages: [AgentMessage] = []
    var isWebSocketConnected: Bool = false
    var spatialAzimuth: Float = 0.0
    var spatialDistance: Float = 1.0
    var spatialVolume: Float = 1.0

    private let webSocketClient: WebSocketClient
    private let spatialAudioPlayer: SpatialAudioPlayer
    private let messageReceiver: AgentMessageReceiver

    init(
        webSocketClient: WebSocketClient,
        spatialAudioPlayer: SpatialAudioPlayer,
        messageReceiver: AgentMessageReceiver
    ) {
        self.webSocketClient = webSocketClient
        self.spatialAudioPlayer = spatialAudioPlayer
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

    func updateSpatialSettings() {
        Task {
            await spatialAudioPlayer.updatePosition(
                azimuth: spatialAzimuth,
                distance: spatialDistance
            )
        }
    }
}
