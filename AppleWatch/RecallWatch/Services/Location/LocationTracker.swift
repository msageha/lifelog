import CoreLocation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "LocationTracker")

actor LocationTracker {
    private var locationManager: CLLocationManager?
    private var lastSentTime: Date?
    private var delegate: LocationDelegate?

    var onLocationUpdate: (@Sendable (CLLocation) -> Void)?

    func start() {
        let manager = CLLocationManager()
        let locationDelegate = LocationDelegate { [weak self] location in
            guard let self else { return }
            Task { await self.handleLocation(location) }
        }

        manager.delegate = locationDelegate
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = Constants.Location.accuracyThreshold
        manager.allowsBackgroundLocationUpdates = true

        locationManager = manager
        delegate = locationDelegate

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }

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
            logger.debug("Location filtered: accuracy \(location.horizontalAccuracy)m exceeds threshold")
            return
        }

        let age = Date().timeIntervalSince(location.timestamp)
        guard age <= Constants.Location.stalenessThreshold else {
            logger.debug("Location filtered: age \(String(format: "%.0f", age))s exceeds staleness threshold")
            return
        }

        if let lastSent = lastSentTime {
            let interval = Date().timeIntervalSince(lastSent)
            guard interval >= Constants.Location.minimumSendInterval else { return }
        }

        lastSentTime = Date()
        onLocationUpdate?(location)
        logger.info("Location sent: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
}

// MARK: - CLLocationManagerDelegate

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let onLocation: @Sendable (CLLocation) -> Void

    init(onLocation: @escaping @Sendable (CLLocation) -> Void) {
        self.onLocation = onLocation
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocation(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location error: \(error)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        logger.info("Location authorization changed: \(status.rawValue)")
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }
}
