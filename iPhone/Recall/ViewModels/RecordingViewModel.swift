import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "RecordingViewModel")

@Observable
@MainActor
final class RecordingViewModel {
    var state: RecordingState = .idle
    var vadProbability: Double = 0.0
    var currentChunkDuration: TimeInterval = 0.0
    var totalChunksRecorded: Int = 0
    var elapsedSeconds: Int = 0

    private var recordingEngine: AudioRecordingEngine?

    func setEngine(_ engine: AudioRecordingEngine) {
        self.recordingEngine = engine
    }

    func startRecording() {
        guard let recordingEngine else {
            logger.error("AudioRecordingEngine not set")
            return
        }
        state = .recording
        Task {
            do {
                try await recordingEngine.start()
                logger.info("Recording started")
            } catch {
                logger.error("Failed to start recording: \(error)")
                state = .idle
            }
        }
    }

    func stopRecording() {
        guard let recordingEngine else {
            logger.error("AudioRecordingEngine not set")
            return
        }
        Task {
            await recordingEngine.stop()
            logger.info("Recording stopped")
        }
        state = .idle
    }

    func toggleRecording() {
        if state == .idle {
            startRecording()
        } else {
            stopRecording()
        }
    }
}
