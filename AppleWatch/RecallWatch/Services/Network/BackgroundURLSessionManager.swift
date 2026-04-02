import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "BGURLSession")

final class BackgroundURLSessionManager: NSObject, Sendable, URLSessionDelegate, URLSessionDataDelegate {
    static let shared = BackgroundURLSessionManager()

    let session: URLSession

    private let completionHandlers = CompletionHandlerStore()

    private override init() {
        let config = URLSessionConfiguration.background(withIdentifier: Constants.Network.backgroundSessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true

        let instance = BackgroundURLSessionManager.allocateUninitializedSession()
        self.session = instance
        super.init()
    }

    private static func allocateUninitializedSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: Constants.Network.backgroundSessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config)
    }

    func setCompletionHandler(_ handler: @escaping @Sendable () -> Void, for identifier: String) {
        completionHandlers.set(handler, for: identifier)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let handler = completionHandlers.remove(for: session.configuration.identifier ?? "") {
            Task { @MainActor in
                handler()
            }
        }
    }
}

private final class CompletionHandlerStore: Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var handlers: [String: @Sendable () -> Void] = [:]

    init() {}

    func set(_ handler: @escaping @Sendable () -> Void, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        handlers[key] = handler
    }

    func remove(for key: String) -> (@Sendable () -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return handlers.removeValue(forKey: key)
    }
}
