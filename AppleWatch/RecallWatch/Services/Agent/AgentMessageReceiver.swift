import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "AgentReceiver")

actor AgentMessageReceiver {
    func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            logger.info("Received text message")
            // TODO: Parse JSON, create AgentMessage in SwiftData
            _ = text

        case .data(let data):
            logger.info("Received binary data (\(data.count) bytes)")
            // TODO: Decode as audio, pass to audio player

        @unknown default:
            break
        }
    }
}
