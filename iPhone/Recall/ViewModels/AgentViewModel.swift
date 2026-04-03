import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "AgentVM")

@Observable
@MainActor
final class AgentViewModel {
    var messages: [AgentMessage] = []
    var isWebSocketConnected: Bool = false
    var connectionStatusText: String = "Disconnected"
    var spatialAzimuth: Float = 0.0
    var spatialDistance: Float = 1.0
    var spatialVolume: Float = 1.0

    private let webSocketClient = WebSocketClient()
    private let spatialAudioPlayer = SpatialAudioPlayer()
    private var messageReceiver: AgentMessageReceiver?
    private let audioEngine = AVAudioEngine()

    func connectWebSocket() {
        guard let urlString = SharedDefaults.string(for: .webSocketServerURL),
              let url = URL(string: urlString) else {
            logger.error("No WebSocket server URL configured")
            connectionStatusText = "No server URL"
            return
        }

        guard let token = KeychainHelper.load(key: "bearerToken"),
              !token.isEmpty else {
            logger.error("No auth token available")
            connectionStatusText = "No auth token"
            return
        }

        Task {
            // Set up spatial audio
            await spatialAudioPlayer.setup(engine: audioEngine)

            // Initialize message receiver
            let receiver = AgentMessageReceiver(spatialAudioPlayer: spatialAudioPlayer)
            self.messageReceiver = receiver

            // Configure message handling
            await webSocketClient.setOnMessage { [weak self] message in
                guard let self else { return }
                await self.messageReceiver?.handleMessage(message)
            }

            await receiver.setOnMessageReceived { [weak self] text, audioPath in
                guard let self else { return }
                await MainActor.run {
                    let agentMessage = AgentMessage(
                        textContent: text,
                        audioFilePath: audioPath
                    )
                    self.messages.append(agentMessage)
                }
            }

            // Monitor connection state
            await webSocketClient.setOnStateChange { [weak self] state in
                guard let self else { return }
                await MainActor.run {
                    switch state {
                    case .connected:
                        self.isWebSocketConnected = true
                        self.connectionStatusText = "Connected"
                    case .disconnected:
                        self.isWebSocketConnected = false
                        self.connectionStatusText = "Disconnected"
                    case .connecting:
                        self.isWebSocketConnected = false
                        self.connectionStatusText = "Connecting..."
                    case .reconnecting(let attempt, let maxAttempts):
                        self.isWebSocketConnected = false
                        self.connectionStatusText = "Reconnecting (\(attempt)/\(maxAttempts))..."
                    case .failed(let reason):
                        self.isWebSocketConnected = false
                        self.connectionStatusText = "Failed: \(reason)"
                    }
                }
            }

            await webSocketClient.connect(url: url, token: token)
        }
    }

    func disconnectWebSocket() {
        Task {
            await webSocketClient.disconnect()
        }
    }

    func updateSpatialSettings() {
        Task {
            await spatialAudioPlayer.updatePosition(
                azimuth: spatialAzimuth,
                distance: spatialDistance
            )
            await spatialAudioPlayer.updateVolume(spatialVolume)
        }
    }
}
