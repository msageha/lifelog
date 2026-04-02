import Foundation

enum Constants {
    enum Audio {
        static let sampleRate: Double = 16000
        static let vadThreshold: Double = 0.25
        static let vadInferenceInterval: TimeInterval = 0.1 // 100ms
        static let chunkMaxDuration: TimeInterval = 30.0
        static let chunkMinDuration: TimeInterval = 5.0
        static let chunkSkipDuration: TimeInterval = 1.0
        static let preMargin: TimeInterval = 3.0
        static let postMargin: TimeInterval = 2.0
        static let opusBitrate: Int = 48000
    }

    enum Location {
        static let accuracyThreshold: Double = 200.0
        static let stalenessThreshold: TimeInterval = 60.0
        static let minimumSendInterval: TimeInterval = 15.0
    }

    enum Upload {
        static let retryInterval: TimeInterval = 60.0
        static let maxRetryDelay: TimeInterval = 300.0
    }

    enum Storage {
        static let capacityLimit: UInt64 = 1_000_000_000 // 1GB
        static let chunksDirectoryName = "chunks"
    }

    enum Network {
        static let backgroundSessionIdentifier = "com.recall.background-upload"
        static let telemetryEndpoint = "/api/telemetry"
        static let ingestEndpoint = "/ingest"
    }

    enum AppGroup {
        static let suiteName = "group.com.recall.shared"
    }
}
