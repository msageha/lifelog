import CoreLocation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "LocationTracker")

actor LocationTracker {
    private var locationManager: CLLocationManager?
    private var lastSentTime: Date?

    func start() {
        // TODO: Configure CLLocationManager
        // - requestAlwaysAuthorization
        // - distanceFilter for background
        // - quality filtering (200m accuracy, 60s staleness)
        // - 15s minimum send interval
        logger.info("Location tracker started")
    }

    func stop() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        logger.info("Location tracker stopped")
    }
}
