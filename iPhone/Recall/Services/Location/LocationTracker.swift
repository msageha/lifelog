import CoreLocation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "LocationTracker")

actor LocationTracker {
    private var locationManager: CLLocationManager?
    private var delegate: LocationDelegate?
    private var lastSentTime: Date?

    var onLocationUpdate: (@Sendable (CLLocation) -> Void)?

    func start() {
        let manager = CLLocationManager()
        let locationDelegate = LocationDelegate { [weak self] location in
            guard let self else { return }
            await self.handleLocation(location)
        }

        manager.delegate = locationDelegate
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()

        self.locationManager = manager
        self.delegate = locationDelegate
        logger.info("Location tracker started")
    }

    func stop() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        delegate = nil
        logger.info("Location tracker stopped")
    }

    private func handleLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy <= Constants.Location.accuracyThreshold else {
            logger.debug("Location rejected: accuracy \(location.horizontalAccuracy)m exceeds threshold")
            return
        }

        guard abs(location.timestamp.timeIntervalSinceNow) <= Constants.Location.stalenessThreshold else {
            logger.debug("Location rejected: stale by \(abs(location.timestamp.timeIntervalSinceNow))s")
            return
        }

        if let lastSent = lastSentTime,
           Date().timeIntervalSince(lastSent) < Constants.Location.minimumSendInterval {
            return
        }

        lastSentTime = Date()
        logger.info("Location accepted: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
}

// MARK: - CLLocationManagerDelegate

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, Sendable {
    private let onLocation: @Sendable (CLLocation) async -> Void

    init(onLocation: @escaping @Sendable (CLLocation) async -> Void) {
        self.onLocation = onLocation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {
            await onLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let logger = Logger(subsystem: "com.recall", category: "LocationTracker")
        logger.error("Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let logger = Logger(subsystem: "com.recall", category: "LocationTracker")
        switch manager.authorizationStatus {
        case .authorizedAlways:
            logger.info("Location authorization: always")
        case .authorizedWhenInUse:
            logger.warning("Location authorization: when in use only — background tracking limited")
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            logger.error("Location authorization denied or restricted")
        case .notDetermined:
            logger.info("Location authorization not determined")
        @unknown default:
            break
        }
    }
}
