import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "ActivityLog")

enum LogCategory: String, Codable, Sendable {
    case state = "STATE"
    case vad = "VAD"
    case chunk = "CHUNK"
    case upload = "UPLOAD"
    case network = "NETWORK"
    case error = "ERROR"
    case health = "HEALTH"
    case location = "LOCATION"
    case telemetry = "TELEMETRY"
    case agent = "AGENT"
}

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let category: LogCategory
    let message: String
}

@Observable
@MainActor
final class ActivityLogger {
    private(set) var recentEntries: [LogEntry] = []
    private let maxMemoryEntries = 200
    private let retentionDays = 7

    private var logDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("logs", isDirectory: true)
    }

    init() {
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    func log(_ category: LogCategory, _ message: String) {
        let entry = LogEntry(timestamp: Date(), category: category, message: message)

        recentEntries.append(entry)
        if recentEntries.count > maxMemoryEntries {
            recentEntries.removeFirst(recentEntries.count - maxMemoryEntries)
        }

        appendToFile(entry)
        logger.debug("[\(category.rawValue)] \(message)")
    }

    private func appendToFile(_ entry: LogEntry) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "\(formatter.string(from: entry.timestamp)).log"
        let fileURL = logDirectory.appendingPathComponent(filename)

        let iso = ISO8601DateFormatter()
        let line = "\(iso.string(from: entry.timestamp)) [\(entry.category.rawValue)] \(entry.message)\n"

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    func cleanOldLogs() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date())!

        for file in files {
            if let values = try? file.resourceValues(forKeys: [.creationDateKey]),
               let created = values.creationDate, created < cutoff {
                try? fm.removeItem(at: file)
            }
        }
    }
}
