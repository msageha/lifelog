import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "UPLOAD")

actor ChunkUploader {
    private var isProcessing = false
    private let retryInterval: TimeInterval = Constants.Upload.retryInterval
    private var processingTask: Task<Void, Never>?

    func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        logger.info("Chunk uploader started")

        processingTask = Task {
            while !Task.isCancelled && isProcessing {
                try? await Task.sleep(for: .seconds(retryInterval))
            }
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
        let endpoint = Constants.Network.ingestEndpoint

        // Build the request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

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

    func uploadWithRetry(fileURL: URL, metadata: ChunkMetadata, maxAttempts: Int = 5) async {
        var attempt = 0
        while attempt < maxAttempts {
            do {
                try await uploadChunk(fileURL: fileURL, metadata: metadata)
                let uploaded = SharedDefaults.integer(for: .uploadedChunkCount) + 1
                SharedDefaults.set(uploaded, for: .uploadedChunkCount)
                SharedDefaults.set(Date(), for: .lastUploadDate)
                let pending = max(0, SharedDefaults.integer(for: .pendingChunkCount) - 1)
                SharedDefaults.set(pending, for: .pendingChunkCount)
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
        logger.error("Upload permanently failed after \(maxAttempts) attempts: \(fileURL.lastPathComponent)")
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
