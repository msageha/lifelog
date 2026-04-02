import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "WebSocket")

actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectDelay: TimeInterval = 60.0
    private let maxRetryCount = 5
    private let baseReconnectDelay: TimeInterval = 1.0

    private var storedURL: URL?
    private var storedToken: String?
    private var isIntentionalDisconnect = false

    var onMessage: (@Sendable (URLSessionWebSocketTask.Message) async -> Void)?

    func connect(url: URL, token: String) {
        isIntentionalDisconnect = false
        storedURL = url
        storedToken = token

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
        isIntentionalDisconnect = true
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        logger.info("WebSocket disconnected intentionally")
    }

    private func receiveLoop() async {
        while isConnected {
            guard let task = webSocketTask else { return }
            do {
                let message = try await task.receive()
                await onMessage?(message)
            } catch {
                logger.error("WebSocket receive error: \(error)")
                isConnected = false
                if !isIntentionalDisconnect {
                    await scheduleReconnect()
                }
                return
            }
        }
    }

    private func scheduleReconnect() async {
        guard !isIntentionalDisconnect else { return }
        guard let url = storedURL, let token = storedToken else {
            logger.warning("Cannot reconnect: no stored URL or token")
            return
        }

        reconnectAttempts += 1
        guard reconnectAttempts <= maxRetryCount else {
            logger.error("Max retry count (\(self.maxRetryCount)) reached, giving up")
            return
        }
        let exponentialDelay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1)), maxReconnectDelay)

        // Add ±20% jitter to avoid thundering herd
        let jitterFactor = Double.random(in: 0.8...1.2)
        let delay = exponentialDelay * jitterFactor

        logger.info("Reconnecting in \(String(format: "%.1f", delay))s (attempt \(self.reconnectAttempts))")

        do {
            try await Task.sleep(for: .seconds(delay))
        } catch {
            logger.debug("Reconnect sleep cancelled")
            return
        }

        guard !isIntentionalDisconnect else { return }
        connect(url: url, token: token)
    }
}
