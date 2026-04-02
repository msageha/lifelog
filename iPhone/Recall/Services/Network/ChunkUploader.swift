import Foundation
import OSLog
import SwiftData
import UIKit

private let logger = Logger(subsystem: "com.recall", category: "UPLOAD")

enum ChunkUploaderError: Error {
    case noServerURL
    case noAuthToken
    case serverError(statusCode: Int)
}

actor ChunkUploader {
    private var isProcessing = false
    private let retryInterval: TimeInterval = Constants.Upload.retryInterval
    private var processingTask: Task<Void, Never>?
    private let modelContainer: ModelContainer
    private var connectivityCheck: @Sendable () async -> Bool

    init(modelContainer: ModelContainer, connectivityCheck: @escaping @Sendable () async -> Bool = { true }) {
        self.modelContainer = modelContainer
        self.connectivityCheck = connectivityCheck
    }

    func setConnectivityCheck(_ check: @escaping @Sendable () async -> Bool) {
        self.connectivityCheck = check
    }

    func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        logger.info("Chunk uploader started")

        processingTask = Task {
            while !Task.isCancelled && isProcessing {
                await processPendingChunks()
                try? await Task.sleep(for: .seconds(retryInterval))
            }
        }
    }

    @MainActor
    private func fetchPendingChunks() throws -> [(id: UUID, filePath: String, startedAt: Date)] {
        let context = modelContainer.mainContext
        let pendingState = UploadState.pending.rawValue
        let failedState = UploadState.failed.rawValue
        var descriptor = FetchDescriptor<AudioChunk>(
            predicate: #Predicate { $0.uploadState == pendingState || $0.uploadState == failedState },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 10
        let chunks = try context.fetch(descriptor)
        return chunks.map { (id: $0.id, filePath: $0.filePath, startedAt: $0.startedAt) }
    }

    private func processPendingChunks() async {
        guard await connectivityCheck() else {
            logger.debug("Network not available, skipping upload cycle")
            return
        }

        do {
            let pendingChunks = try await fetchPendingChunks()
            guard !pendingChunks.isEmpty else { return }

            logger.info("Processing \(pendingChunks.count) pending chunks")

            for chunk in pendingChunks {
                guard !Task.isCancelled && isProcessing else { break }
                let fileURL = URL(fileURLWithPath: chunk.filePath)
                let metadata = ChunkMetadata(
                    deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                    startedAt: chunk.startedAt,
                    timezone: TimeZone.current.identifier
                )
                await uploadWithRetry(fileURL: fileURL, metadata: metadata, chunkId: chunk.id)
            }
        } catch {
            logger.error("Failed to fetch pending chunks: \(error.localizedDescription)")
        }
    }

    func stopProcessing() {
        isProcessing = false
        processingTask?.cancel()
        processingTask = nil
        logger.info("Chunk uploader stopped")
    }

    func uploadChunk(fileURL: URL, metadata: ChunkMetadata) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"

        guard let baseURLString = SharedDefaults.string(for: .uploadServerURL),
              let baseURL = URL(string: baseURLString) else {
            throw ChunkUploaderError.noServerURL
        }

        guard let token = KeychainHelper.load(key: "bearerToken"),
              !token.isEmpty else {
            throw ChunkUploaderError.noAuthToken
        }

        let url = baseURL.appendingPathComponent(Constants.Network.ingestEndpoint)

        // Build the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Assemble multipart body
        let body = try buildMultipartBody(
            boundary: boundary,
            fileURL: fileURL,
            metadata: metadata
        )

        // Write body to a temporary file for background upload
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try body.write(to: tempURL)

        // Submit via Background URLSession
        let session = BackgroundURLSessionManager.shared.session
        let uploadTask = session.uploadTask(with: request, fromFile: tempURL)
        uploadTask.resume()

        logger.info("Upload queued: \(fileURL.lastPathComponent) (\(body.count) bytes)")
    }

    // MARK: - Retry

    func uploadWithRetry(fileURL: URL, metadata: ChunkMetadata, chunkId: UUID? = nil, maxAttempts: Int = 5) async {
        var attempt = 0
        while attempt < maxAttempts {
            do {
                try await uploadChunk(fileURL: fileURL, metadata: metadata)
                let uploaded = SharedDefaults.integer(for: .uploadedChunkCount) + 1
                SharedDefaults.set(uploaded, for: .uploadedChunkCount)
                SharedDefaults.set(Date(), for: .lastUploadDate)
                let pending = max(0, SharedDefaults.integer(for: .pendingChunkCount) - 1)
                SharedDefaults.set(pending, for: .pendingChunkCount)
                if let chunkId {
                    await updateChunkState(chunkId: chunkId, state: .uploaded)
                }
                logger.info("Upload stats updated: uploaded=\(uploaded), pending=\(pending)")
                return
            } catch {
                attempt += 1
                let delay = retryInterval * pow(2.0, Double(attempt - 1))
                let cappedDelay = min(delay, Constants.Upload.maxRetryDelay)
                logger.warning("Upload failed (attempt \(attempt)/\(maxAttempts)): \(error.localizedDescription). Retrying in \(cappedDelay)s")
                try? await Task.sleep(for: .seconds(cappedDelay))
            }
        }
        if let chunkId {
            await updateChunkState(chunkId: chunkId, state: .failed)
        }
        logger.error("Upload permanently failed after \(maxAttempts) attempts: \(fileURL.lastPathComponent)")
    }

    @MainActor
    private func updateChunkState(chunkId: UUID, state: UploadState) {
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<AudioChunk>(
            predicate: #Predicate { $0.id == chunkId }
        )
        descriptor.fetchLimit = 1
        if let chunk = try? context.fetch(descriptor).first {
            chunk.state = state
            try? context.save()
        }
    }

    // MARK: - Multipart Builder

    private func buildMultipartBody(
        boundary: String,
        fileURL: URL,
        metadata: ChunkMetadata
    ) throws -> Data {
        var body = Data()

        // Part 1: Audio file
        body.appendString("--\(boundary)\r\n")
        body.appendString(
            "Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"
        )
        body.appendString("Content-Type: application/octet-stream\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        body.appendString("\r\n")

        // Part 2: Metadata JSON
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"metadata\"\r\n")
        body.appendString("Content-Type: application/json\r\n\r\n")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        body.append(try encoder.encode(metadata))
        body.appendString("\r\n")

        // Closing boundary
        body.appendString("--\(boundary)--\r\n")

        return body
    }
}

// MARK: - ChunkMetadata

struct ChunkMetadata: Codable, Sendable {
    let deviceId: String
    let startedAt: Date
    let timezone: String
}

// MARK: - Data Extension

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
