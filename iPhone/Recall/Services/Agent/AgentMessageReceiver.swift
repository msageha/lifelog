import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.recall", category: "AgentReceiver")

struct AgentTextPayload: Codable, Sendable {
    let type: String
    let text: String?
    let audioPath: String?
}

actor AgentMessageReceiver {
    private let spatialAudioPlayer: SpatialAudioPlayer

    private var onMessageReceived: (@Sendable (String, String?) async -> Void)?

    func setOnMessageReceived(_ handler: @escaping @Sendable (String, String?) async -> Void) {
        onMessageReceived = handler
    }

    init(spatialAudioPlayer: SpatialAudioPlayer) {
        self.spatialAudioPlayer = spatialAudioPlayer
    }

    func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            logger.info("Received text message")
            await handleTextMessage(text)

        case .data(let data):
            logger.info("Received binary data (\(data.count) bytes)")
            await handleBinaryMessage(data)

        @unknown default:
            logger.warning("Received unknown message type")
        }
    }

    private func handleTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else {
            logger.error("Failed to convert text message to data")
            return
        }

        do {
            let payload = try JSONDecoder().decode(AgentTextPayload.self, from: data)

            switch payload.type {
            case "text":
                let content = payload.text ?? ""
                logger.info("Parsed text message: \(content.prefix(50))")
                await onMessageReceived?(content, nil)

            case "audio":
                if let audioPath = payload.audioPath {
                    logger.info("Parsed audio message with path: \(audioPath)")
                    await onMessageReceived?("", audioPath)
                }

            default:
                logger.warning("Unknown message type: \(payload.type)")
            }
        } catch {
            logger.error("Failed to parse JSON message: \(error.localizedDescription)")
        }
    }

    private func handleBinaryMessage(_ data: Data) async {
        do {
            try await spatialAudioPlayer.play(audioData: data)
        } catch {
            logger.error("Failed to play audio data: \(error.localizedDescription)")
        }
    }
}
