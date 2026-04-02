import Foundation

@Observable
@MainActor
final class ConfigViewModel {
    var uploadServerURL: String = "" {
        didSet { SharedDefaults.set(uploadServerURL, for: .uploadServerURL) }
    }
    var telemetryServerURL: String = "" {
        didSet { SharedDefaults.set(telemetryServerURL, for: .telemetryServerURL) }
    }
    var webSocketServerURL: String = "" {
        didSet { SharedDefaults.set(webSocketServerURL, for: .webSocketServerURL) }
    }
    var bearerToken: String = ""

    var isHealthEnabled: Bool = true {
        didSet { SharedDefaults.set(isHealthEnabled, for: .isHealthEnabled) }
    }
    var isLocationEnabled: Bool = true {
        didSet { SharedDefaults.set(isLocationEnabled, for: .isLocationEnabled) }
    }
    var isBackgroundLocationEnabled: Bool = true
    var isMotionEnabled: Bool = true {
        didSet { SharedDefaults.set(isMotionEnabled, for: .isMotionEnabled) }
    }
    var isWiFiOnly: Bool = true {
        didSet { SharedDefaults.set(isWiFiOnly, for: .wifiOnlyUpload) }
    }

    var storageUsedBytes: UInt64 = 0
    var storageCapacityBytes: UInt64 = Constants.Storage.capacityLimit

    init() {
        loadFromKeychain()
        loadFromDefaults()
    }

    func saveServerSettings() {
        try? KeychainHelper.save(key: "bearerToken", value: bearerToken)
        SharedDefaults.set(uploadServerURL, for: .uploadServerURL)
        SharedDefaults.set(telemetryServerURL, for: .telemetryServerURL)
        SharedDefaults.set(webSocketServerURL, for: .webSocketServerURL)
    }

    func applyQRConfig(_ config: QRServerConfig) {
        uploadServerURL = config.uploadURL
        telemetryServerURL = config.telemetryURL
        webSocketServerURL = config.webSocketURL
        if let token = config.token {
            bearerToken = token
        }
        saveServerSettings()
    }

    private func loadFromKeychain() {
        bearerToken = KeychainHelper.load(key: "bearerToken") ?? ""
    }

    private func loadFromDefaults() {
        uploadServerURL = SharedDefaults.string(for: .uploadServerURL) ?? ""
        telemetryServerURL = SharedDefaults.string(for: .telemetryServerURL) ?? ""
        webSocketServerURL = SharedDefaults.string(for: .webSocketServerURL) ?? ""
        isWiFiOnly = SharedDefaults.bool(for: .wifiOnlyUpload)
        isHealthEnabled = SharedDefaults.bool(for: .isHealthEnabled)
        isLocationEnabled = SharedDefaults.bool(for: .isLocationEnabled)
        isMotionEnabled = SharedDefaults.bool(for: .isMotionEnabled)
    }
}

struct QRServerConfig: Codable, Sendable {
    let uploadURL: String
    let telemetryURL: String
    let webSocketURL: String
    let token: String?
}
