import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "RecordingVM")

@Observable
@MainActor
final class RecordingViewModel {
    var state: RecordingState = .idle
    var vadProbability: Double = 0.0
    var currentChunkDuration: TimeInterval = 0.0
    var totalChunksRecorded: Int = 0
    var elapsedSeconds: Int = 0

    private let engine: AudioRecordingEngine
    private var timerTask: Task<Void, Never>?

    init(engine: AudioRecordingEngine) {
        self.engine = engine
    }

    func startRecording() {
        state = .recording
        Task {
            do {
                try await engine.start()
                logger.info("Recording started")
            } catch {
                logger.error("Failed to start recording: \(error)")
                state = .idle
            }
        }
        startTimer()
    }

    func stopRecording() {
        state = .idle
        Task {
            await engine.stop()
            logger.info("Recording stopped")
        }
        stopTimer()
    }

    func toggleRecording() {
        if state == .idle {
            startRecording()
        } else {
            stopRecording()
        }
    }

    private func startTimer() {
        elapsedSeconds = 0
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
