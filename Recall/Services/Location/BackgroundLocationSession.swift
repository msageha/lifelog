import CoreLocation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "BackgroundLocation")

actor BackgroundLocationSession {
    private var session: CLBackgroundActivitySession?

    func start() {
        session = CLBackgroundActivitySession()
        logger.info("Background location session started")
    }

    func stop() {
        session?.invalidate()
        session = nil
        logger.info("Background location session stopped")
    }
}
