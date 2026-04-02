import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "ChunkManager")

actor ChunkManager {
    private var currentChunkStart: Date?
    private var accumulatedSamples: [Float] = []

    func onSpeechStart() {
        currentChunkStart = Date()
        logger.debug("Speech start detected")
    }

    func onSpeechEnd() async {
        guard let start = currentChunkStart else { return }
        let duration = Date().timeIntervalSince(start)

        guard duration >= Constants.Audio.chunkSkipDuration else {
            logger.debug("Chunk too short (\(duration)s), skipping")
            currentChunkStart = nil
            return
        }

        // TODO: Save chunk with pre/post margins via OpusEncoder
        logger.info("Chunk saved: \(duration)s")
        currentChunkStart = nil
        accumulatedSamples.removeAll()
    }

    func appendSamples(_ samples: [Float]) {
        accumulatedSamples.append(contentsOf: samples)
    }
}
