import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "ChunkStorage")

actor ChunkStorageManager {
    private let chunksDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        chunksDirectory = docs.appendingPathComponent("chunks", isDirectory: true)
        try? FileManager.default.createDirectory(at: chunksDirectory, withIntermediateDirectories: true)
    }

    func enforceStorageCap() throws {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: chunksDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]
        ) else { return }

        var totalSize: UInt64 = 0
        var fileInfos: [(url: URL, size: UInt64, date: Date)] = []

        for url in files {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            let size = UInt64(values.fileSize ?? 0)
            let date = values.creationDate ?? .distantPast
            totalSize += size
            fileInfos.append((url, size, date))
        }

        guard totalSize > Constants.Storage.capacityLimit else { return }

        fileInfos.sort { $0.date < $1.date }

        for info in fileInfos {
            guard totalSize > Constants.Storage.capacityLimit else { break }
            try fm.removeItem(at: info.url)
            totalSize -= info.size
            logger.info("Evicted old chunk: \(info.url.lastPathComponent)")
        }
    }
}
