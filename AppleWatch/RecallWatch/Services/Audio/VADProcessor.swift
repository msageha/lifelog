import CoreML
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "VADProcessor")

actor VADProcessor {
    private var model: MLModel?
    private(set) var currentProbability: Double = 0.0
    private(set) var isSpeechDetected: Bool = false

    func loadModel() throws {
        // TODO: Load SileroVAD.mlmodel
        logger.info("VAD model loaded")
    }

    func process(samples: [Float]) -> Double {
        // TODO: Run CoreML inference on audio samples
        // Returns speech probability 0.0...1.0
        let probability = 0.0
        currentProbability = probability
        isSpeechDetected = probability >= Constants.Audio.vadThreshold
        return probability
    }
}
