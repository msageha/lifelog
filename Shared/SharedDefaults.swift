import Foundation

enum SharedDefaultsKey: String, Sendable {
    case recordingState = "recordingState"
    case isRecordingEnabled = "isRecordingEnabled"
    case isLocationEnabled = "isLocationEnabled"
    case isHealthEnabled = "isHealthEnabled"
    case isMotionEnabled = "isMotionEnabled"
    case wifiOnlyUpload = "wifiOnlyUpload"
}

struct SharedDefaults: Sendable {
    static let suiteName = "group.com.recall.shared"

    static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func bool(for key: SharedDefaultsKey) -> Bool {
        store.bool(forKey: key.rawValue)
    }

    static func set(_ value: Bool, for key: SharedDefaultsKey) {
        store.set(value, forKey: key.rawValue)
    }

    static func string(for key: SharedDefaultsKey) -> String? {
        store.string(forKey: key.rawValue)
    }

    static func set(_ value: String, for key: SharedDefaultsKey) {
        store.set(value, forKey: key.rawValue)
    }

    static var recordingState: RecordingState {
        get {
            guard let raw = string(for: .recordingState) else { return .idle }
            return RecordingState(rawValue: raw) ?? .idle
        }
        set {
            set(newValue.rawValue, for: .recordingState)
        }
    }
}
