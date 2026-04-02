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
        // TODO: Save state and prepare for suspension
    }
}
