import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.recall", category: "UploadViewModel")

@Observable
@MainActor
final class UploadViewModel {
    var pendingCount: Int = 0
    var uploadedCount: Int = 0
    var failedCount: Int = 0
    var isUploading: Bool = false
    var serverConnected: Bool = false

    private let chunkUploader: ChunkUploader
    private let modelContainer: ModelContainer

    init(chunkUploader: ChunkUploader, modelContainer: ModelContainer) {
        self.chunkUploader = chunkUploader
        self.modelContainer = modelContainer
    }

    func setConnectivityCheck(_ check: @escaping @Sendable () async -> Bool) {
        Task {
            await chunkUploader.setConnectivityCheck(check)
        }
    }

    func startProcessing() {
        Task {
            await chunkUploader.startProcessing()
            isUploading = true
            logger.info("Upload processing started")
        }
        refreshCounts()
    }

    func retryFailed() {
        let context = modelContainer.mainContext
        let failedState = UploadState.failed.rawValue
        let descriptor = FetchDescriptor<AudioChunk>(
            predicate: #Predicate { $0.uploadState == failedState }
        )
        do {
            let failedChunks = try context.fetch(descriptor)
            for chunk in failedChunks {
                chunk.state = .pending
                chunk.uploadAttempts = 0
            }
            try context.save()
            logger.info("Reset \(failedChunks.count) failed chunks to pending")
            refreshCounts()
        } catch {
            logger.error("Failed to retry failed chunks: \(error)")
        }
    }

    func recoverStuckUploads() {
        let context = modelContainer.mainContext
        let uploadingState = UploadState.uploading.rawValue
        let descriptor = FetchDescriptor<AudioChunk>(
            predicate: #Predicate { $0.uploadState == uploadingState }
        )
        do {
            let stuckChunks = try context.fetch(descriptor)
            for chunk in stuckChunks {
                chunk.state = .pending
            }
            try context.save()
            logger.info("Recovered \(stuckChunks.count) stuck uploads")
            refreshCounts()
        } catch {
            logger.error("Failed to recover stuck uploads: \(error)")
        }
    }

    func refreshCounts() {
        pendingCount = SharedDefaults.integer(for: .pendingChunkCount)
        uploadedCount = SharedDefaults.integer(for: .uploadedChunkCount)
        // Count failed from SwiftData
        let context = modelContainer.mainContext
        let failedState = UploadState.failed.rawValue
        let descriptor = FetchDescriptor<AudioChunk>(
            predicate: #Predicate { $0.uploadState == failedState }
        )
        failedCount = (try? context.fetchCount(descriptor)) ?? 0
    }
}
