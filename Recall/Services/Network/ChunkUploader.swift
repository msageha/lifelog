import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "ChunkUploader")

actor ChunkUploader {
    private var isProcessing = false
    private let retryInterval: TimeInterval = 60.0

    func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        logger.info("Chunk uploader started")
        // TODO: Periodically fetch pending chunks from SwiftData and upload
    }

    func stopProcessing() {
        isProcessing = false
        logger.info("Chunk uploader stopped")
    }

    func uploadChunk(fileURL: URL, metadata: ChunkMetadata) async throws {
        // TODO: Build multipart form data, POST to /ingest
        // Mark as uploaded on 2xx, retry with exponential backoff on failure
        logger.info("Uploading chunk: \(fileURL.lastPathComponent)")
    }
}

struct ChunkMetadata: Codable, Sendable {
    let deviceId: String
    let startedAt: Date
    let timezone: String
}
