import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "OpusEncoder")

actor OpusEncoder {
    private let outputDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        outputDirectory = docs.appendingPathComponent("chunks", isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func encode(samples: [Float], startedAt: Date) async throws -> URL {
        let filename = "\(ISO8601DateFormatter().string(from: startedAt)).caf"
        let outputURL = outputDirectory.appendingPathComponent(filename)

        // TODO: Encode PCM Float32 -> Opus/CAF at 48kbps, 16kHz
        logger.info("Encoded chunk to \(outputURL.lastPathComponent)")
        return outputURL
    }
}
