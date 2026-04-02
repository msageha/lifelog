import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.recall.watch", category: "AgentReceiver")

actor AgentMessageReceiver {
    private let modelContainer: ModelContainer
    private let audioPlayer: AudioPlayer

    init(modelContainer: ModelContainer, audioPlayer: AudioPlayer) {
        self.modelContainer = modelContainer
        self.audioPlayer = audioPlayer
    }

    func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            logger.info("Received text message")
            await handleTextMessage(text)

        case .data(let data):
            logger.info("Received binary data (\(data.count) bytes)")
            await handleAudioData(data)

        @unknown default:
            break
        }
    }

    private func handleTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else {
            logger.warning("Failed to encode text message as UTF-8")
            return
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.warning("Message is not a JSON object")
                return
            }

            let textContent = json["text"] as? String ?? text
            await saveMessage(textContent: textContent)
        } catch {
            logger.error("JSON parse error: \(error)")
            await saveMessage(textContent: text)
        }
    }

    @MainActor
    private func saveMessage(textContent: String) {
        let context = modelContainer.mainContext
        let agentMessage = AgentMessage(textContent: textContent)
        context.insert(agentMessage)
        do {
            try context.save()
            logger.info("Saved agent message to SwiftData")
        } catch {
            logger.error("Failed to save agent message: \(error)")
        }
    }

    private func handleAudioData(_ data: Data) async {
        do {
            try await audioPlayer.play(audioData: data)
        } catch {
            logger.error("Failed to play audio: \(error)")
        }
    }
}
