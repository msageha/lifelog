import ActivityKit
import Foundation

struct RecallActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        var isRecording: Bool
        var elapsedSeconds: Int
        var chunkCount: Int
        var vadProbability: Double
    }
}
