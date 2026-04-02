import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "WebSocket")

actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectDelay: TimeInterval = 60.0

    var onMessage: (@Sendable (URLSessionWebSocketTask.Message) async -> Void)?

    func connect(url: URL, token: String) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()
        webSocketTask = task
        isConnected = true
        reconnectAttempts = 0

        logger.info("WebSocket connected to \(url.absoluteString)")
        Task { await receiveLoop() }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        logger.info("WebSocket disconnected")
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }
        do {
            let message = try await task.receive()
            await onMessage?(message)
            await receiveLoop()
        } catch {
            logger.error("WebSocket receive error: \(error)")
            isConnected = false
            await scheduleReconnect()
        }
    }

    private func scheduleReconnect() async {
        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), maxReconnectDelay)
        logger.info("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts))")
        try? await Task.sleep(for: .seconds(delay))
        // TODO: Reconnect using stored URL and token
    }
}
