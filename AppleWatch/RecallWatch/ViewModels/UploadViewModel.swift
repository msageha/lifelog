import Foundation

@Observable
@MainActor
final class UploadViewModel {
    var pendingCount: Int = 0
    var uploadedCount: Int = 0
    var failedCount: Int = 0
    var isUploading: Bool = false
    var serverConnected: Bool = false

    func startProcessing() {
        // TODO: Start ChunkUploader
    }

    func retryFailed() {
        // TODO: Reset failed chunks to pending
    }

    func recoverStuckUploads() {
        // TODO: Reset stuck uploading state to pending
    }
}
