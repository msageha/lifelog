import Foundation
import SwiftData

enum UploadState: String, Codable, Sendable {
    case pending
    case uploading
    case uploaded
    case failed
}

@Model
final class AudioChunk {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var vadRatio: Double
    var filePath: String
    var uploadState: String
    var uploadAttempts: Int
    var createdAt: Date

    init(
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval,
        vadRatio: Double,
        filePath: String
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.vadRatio = vadRatio
        self.filePath = filePath
        self.uploadState = UploadState.pending.rawValue
        self.uploadAttempts = 0
        self.createdAt = Date()
    }

    var state: UploadState {
        get { UploadState(rawValue: uploadState) ?? .pending }
        set { uploadState = newValue.rawValue }
    }
}
