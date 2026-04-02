import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "CHUNK")

actor ChunkManager {
    private var currentChunkStart: Date?
    private var accumulatedSamples: [Float] = []
    private var isRecordingChunk = false
    private var postMarginTask: Task<Void, Never>?
    private var maxDurationTask: Task<Void, Never>?

    private let opusEncoder: OpusEncoder
    private let storageManager: ChunkStorageManager

    private(set) var isSpeechActive = false

    init(opusEncoder: OpusEncoder, storageManager: ChunkStorageManager) {
        self.opusEncoder = opusEncoder
        self.storageManager = storageManager
    }

    // MARK: - VAD Notifications

    func onSpeechStart(preMarginSamples: [Float]) {
        isSpeechActive = true

        // Cancel any pending post-margin finalization
        postMarginTask?.cancel()
        postMarginTask = nil

        guard !isRecordingChunk else {
            // Already recording a chunk (speech resumed within post-margin)
            logger.debug("Speech resumed within post-margin, continuing chunk")
            return
        }

        // Start a new chunk with pre-margin audio
        let preMarginDuration = Constants.Audio.preMargin
        currentChunkStart = Date().addingTimeInterval(-preMarginDuration)
        accumulatedSamples = preMarginSamples
        isRecordingChunk = true

        startMaxDurationTimer()
        logger.debug("Chunk recording started (pre-margin: \(preMarginSamples.count) samples)")
    }

    func onSpeechEnd() {
        isSpeechActive = false
        logger.debug("Speech ended, starting post-margin (\(Constants.Audio.postMargin)s)")

        postMarginTask = Task {
            try? await Task.sleep(for: .seconds(Constants.Audio.postMargin))
            guard !Task.isCancelled else { return }
            finalizeChunk()
        }
    }

    func appendSamples(_ samples: [Float]) {
        guard isRecordingChunk else { return }
        accumulatedSamples.append(contentsOf: samples)
    }

    // MARK: - Chunk Lifecycle

    private func startMaxDurationTimer() {
        maxDurationTask?.cancel()
        maxDurationTask = Task {
            try? await Task.sleep(for: .seconds(Constants.Audio.chunkMaxDuration))
            guard !Task.isCancelled else { return }
            forceSplitChunk()
        }
    }

    private func forceSplitChunk() {
        logger.info("Chunk reached max duration (\(Constants.Audio.chunkMaxDuration)s), splitting")
        saveAndResetChunk()

        if isSpeechActive {
            // Speech is still ongoing – start a new chunk immediately
            currentChunkStart = Date()
            accumulatedSamples = []
            isRecordingChunk = true
            startMaxDurationTimer()
        }
    }

    private func finalizeChunk() {
        maxDurationTask?.cancel()
        maxDurationTask = nil
        saveAndResetChunk()
    }

    private func saveAndResetChunk() {
        guard let start = currentChunkStart else { return }
        let duration = Date().timeIntervalSince(start)
        let samples = accumulatedSamples

        resetState()

        if duration < Constants.Audio.chunkMinDuration {
            logger.debug("Chunk too short (\(String(format: "%.1f", duration))s < \(Constants.Audio.chunkMinDuration)s), discarding")
            return
        }

        let chunkStart = start
        Task {
            do {
                let url = try await opusEncoder.encode(samples: samples, startedAt: chunkStart)
                try await storageManager.enforceStorageCap()
                logger.info("Chunk saved: \(String(format: "%.1f", duration))s → \(url.lastPathComponent)")
            } catch {
                logger.error("Failed to encode/save chunk: \(error.localizedDescription)")
            }
        }
    }

    private func resetState() {
        currentChunkStart = nil
        accumulatedSamples = []
        isRecordingChunk = false
        postMarginTask?.cancel()
        postMarginTask = nil
        maxDurationTask?.cancel()
        maxDurationTask = nil
    }
}
