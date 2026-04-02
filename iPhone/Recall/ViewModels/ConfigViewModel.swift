import Foundation

@Observable
@MainActor
final class ConfigViewModel {
    var uploadServerURL: String = ""
    var telemetryServerURL: String = ""
    var webSocketServerURL: String = ""
    var bearerToken: String = ""

    var isHealthEnabled: Bool = true
    var isLocationEnabled: Bool = true
    var isBackgroundLocationEnabled: Bool = true
    var isMotionEnabled: Bool = true
    var isWiFiOnly: Bool = true

    var storageUsedBytes: UInt64 = 0
    var storageCapacityBytes: UInt64 = Constants.Storage.capacityLimit

    init() {
        loadFromKeychain()
        loadFromDefaults()
    }

    func saveServerSettings() {
        try? KeychainHelper.save(key: "bearerToken", value: bearerToken)
        // TODO: Persist server URLs
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
