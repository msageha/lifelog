import Foundation

@Observable
@MainActor
final class RecordingViewModel {
    var state: RecordingState = .idle
    var vadProbability: Double = 0.0
    var currentChunkDuration: TimeInterval = 0.0
    var totalChunksRecorded: Int = 0
    var elapsedSeconds: Int = 0

    func startRecording() {
        state = .recording
        // TODO: Start AudioRecordingEngine
    }

    func stopRecording() {
        state = .idle
        // TODO: Stop AudioRecordingEngine
    }

    func toggleRecording() {
        if state == .idle {
            startRecording()
        } else {
            stopRecording()
        }
    }
}
