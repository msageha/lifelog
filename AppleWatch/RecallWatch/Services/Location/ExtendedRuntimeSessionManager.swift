import Foundation
import OSLog
import WatchKit

private let logger = Logger(subsystem: "com.recall.watch", category: "ExtendedRuntime")

@MainActor
final class ExtendedRuntimeSessionManager: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?

    func start() {
        guard session == nil else { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start()
        session = newSession
        logger.info("Extended runtime session started")
    }

    func stop() {
        session?.invalidate()
        session = nil
        logger.info("Extended runtime session stopped")
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        if let error {
            logger.error("Extended runtime session invalidated: \(error)")
        } else {
            logger.info("Extended runtime session invalidated: reason=\(reason.rawValue)")
        }
        Task { @MainActor in
            self.session = nil
        }
    }

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        logger.info("Extended runtime session did start")
    }

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {
        logger.warning("Extended runtime session will expire soon")
        saveStateBeforeExpiration()
    }

    private nonisolated func saveStateBeforeExpiration() {
        let recordingState = SharedDefaults.recordingState
        SharedDefaults.set(recordingState.rawValue, for: .recordingState)

        let pendingChunks = SharedDefaults.integer(for: .pendingChunkCount)
        SharedDefaults.set(pendingChunks, for: .pendingChunkCount)

        let now = Date().timeIntervalSince1970
        SharedDefaults.set(now, for: .lastLocationTimestamp)

        SharedDefaults.store.synchronize()
        logger.info("State saved before expiration: recording=\(recordingState.rawValue), pendingChunks=\(pendingChunks), locationTimestamp=\(now)")
    }

    nonisolated func restoreStateAfterResume() {
        let recordingState = SharedDefaults.recordingState
        let pendingChunks = SharedDefaults.integer(for: .pendingChunkCount)
        let lastLocationTs = SharedDefaults.double(for: .lastLocationTimestamp)

        logger.info("State restored: recording=\(recordingState.rawValue), pendingChunks=\(pendingChunks), lastLocation=\(lastLocationTs)")
    }
}
