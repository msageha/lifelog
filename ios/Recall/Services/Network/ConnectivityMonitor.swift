import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "Connectivity")

@Observable
@MainActor
final class ConnectivityMonitor {
    private(set) var isConnected = false
    private(set) var isWiFi = false
    private(set) var isExpensive = false
    private(set) var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.recall.connectivity")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isWiFi = path.usesInterfaceType(.wifi)
                self?.isExpensive = path.isExpensive
                self?.isConstrained = path.isConstrained
                logger.debug("Network: connected=\(path.status == .satisfied) wifi=\(path.usesInterfaceType(.wifi))")
            }
        }
        monitor.start(queue: queue)
        logger.info("Connectivity monitor started")
    }

    func stop() {
        monitor.cancel()
        logger.info("Connectivity monitor stopped")
    }

    var canUpload: Bool {
        guard isConnected else { return false }
        if SharedDefaults.bool(for: .wifiOnlyUpload) {
            return isWiFi
        }
        return true
    }
}
