import Foundation

enum RecordingState: String, Codable, Sendable {
    case idle
    case listening
    case recording
}
