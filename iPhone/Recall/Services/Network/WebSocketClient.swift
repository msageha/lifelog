import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "WebSocket")

enum WebSocketConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int, maxAttempts: Int)
    case failed(reason: String)
}

actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private(set) var connectionState: WebSocketConnectionState = .disconnected
    private var reconnectAttempts = 0
    private let maxReconnectDelay: TimeInterval = 60.0
    private let baseReconnectDelay: TimeInterval = 1.0
    private let maxRetryCount: Int = 5

    private var storedURL: URL?
    private var storedToken: String?
    private var isIntentionalDisconnect = false

    private var onMessage: (@Sendable (URLSessionWebSocketTask.Message) async -> Void)?
    private var onStateChange: (@Sendable (WebSocketConnectionState) async -> Void)?

    func setOnMessage(_ handler: @escaping @Sendable (URLSessionWebSocketTask.Message) async -> Void) {
        onMessage = handler
    }

    func setOnStateChange(_ handler: @escaping @Sendable (WebSocketConnectionState) async -> Void) {
        onStateChange = handler
    }

    func connect(url: URL, token: String) {
        isIntentionalDisconnect = false
        storedURL = url
        storedToken = token

        updateState(.connecting)

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()
        webSocketTask = task
        reconnectAttempts = 0

        updateState(.connected)
        logger.info("WebSocket connected to \(url.absoluteString)")
        Task { await receiveLoop() }
    }

    func disconnect() {
        isIntentionalDisconnect = true
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        updateState(.disconnected)
        logger.info("WebSocket disconnected intentionally")
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }
        do {
            let message = try await task.receive()
            await onMessage?(message)
            await receiveLoop()
        } catch {
            logger.error("WebSocket receive error: \(error)")
            if !isIntentionalDisconnect {
                await scheduleReconnect()
            } else {
                updateState(.disconnected)
            }
        }
    }

    private func scheduleReconnect() async {
        guard !isIntentionalDisconnect else { return }
        guard let url = storedURL, let token = storedToken else {
            logger.warning("Cannot reconnect: no stored URL or token")
            updateState(.failed(reason: "No stored URL or token"))
            return
        }

        reconnectAttempts += 1

        if reconnectAttempts > maxRetryCount {
            logger.error("Max retry count (\(self.maxRetryCount)) reached. Giving up.")
            updateState(.failed(reason: "Max retry count (\(self.maxRetryCount)) reached"))
            return
        }

        updateState(.reconnecting(attempt: reconnectAttempts, maxAttempts: maxRetryCount))

        let exponentialDelay = min(baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1)), maxReconnectDelay)

        // Add ±20% jitter to avoid thundering herd
        let jitterFactor = Double.random(in: 0.8...1.2)
        let delay = exponentialDelay * jitterFactor

        logger.info("Reconnecting in \(String(format: "%.1f", delay))s (attempt \(self.reconnectAttempts)/\(self.maxRetryCount))")

        do {
            try await Task.sleep(for: .seconds(delay))
        } catch {
            logger.debug("Reconnect sleep cancelled")
            return
        }

        guard !isIntentionalDisconnect else { return }
        connect(url: url, token: token)
    }

    private func updateState(_ newState: WebSocketConnectionState) {
        connectionState = newState
        Task { await onStateChange?(newState) }
    }
}
