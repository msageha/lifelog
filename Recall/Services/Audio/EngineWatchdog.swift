import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "EngineWatchdog")

actor EngineWatchdog {
    private var lastWriteTime: Date = Date()
    private var watchdogTask: Task<Void, Never>?
    private let stallThreshold: TimeInterval = 10.0

    func updateWriteTime() {
        lastWriteTime = Date()
    }

    func start(onStall: @escaping @Sendable () async -> Void) {
        watchdogTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                let elapsed = Date().timeIntervalSince(lastWriteTime)
                if elapsed > stallThreshold {
                    logger.warning("Engine stall detected (\(elapsed)s since last write)")
                    await onStall()
                    lastWriteTime = Date()
                }
            }
        }
    }

    func stop() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }
}
