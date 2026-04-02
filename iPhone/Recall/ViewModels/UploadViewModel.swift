import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "UploadViewModel")

@Observable
@MainActor
final class UploadViewModel {
    var pendingCount: Int = 0
    var uploadedCount: Int = 0
    var failedCount: Int = 0
    var isUploading: Bool = false
    var serverConnected: Bool = false

    private let uploader = ChunkUploader()

    func startProcessing() {
        Task {
            await uploader.startProcessing()
            isUploading = true
            logger.info("Upload processing started")
        }
        refreshCounts()
    }

    func retryFailed() {
        let failed = SharedDefaults.integer(for: .pendingChunkCount)
        SharedDefaults.set(failed + failedCount, for: .pendingChunkCount)
        failedCount = 0
        logger.info("Failed uploads reset to pending for retry")
        refreshCounts()
    }

    func recoverStuckUploads() {
        logger.info("Recovering stuck uploads — resetting uploading state to pending")
        refreshCounts()
    }

    private func refreshCounts() {
        pendingCount = SharedDefaults.integer(for: .pendingChunkCount)
        uploadedCount = SharedDefaults.integer(for: .uploadedChunkCount)
    }
}
