import CoreML
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "VADProcessor")

actor VADProcessor {
    private var model: MLModel?
    private(set) var currentProbability: Double = 0.0
    private(set) var isSpeechDetected: Bool = false

    private var h: MLMultiArray?
    private var c: MLMultiArray?

    func loadModel() throws {
        guard let modelURL = Bundle.main.url(forResource: "SileroVAD", withExtension: "mlmodelc") else {
            logger.warning("SileroVAD model not found in bundle, using fallback")
            return
        }
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        model = try MLModel(contentsOf: modelURL, configuration: config)

        let shape: [NSNumber] = [1, 64]
        h = try MLMultiArray(shape: shape, dataType: .float32)
        c = try MLMultiArray(shape: shape, dataType: .float32)

        logger.info("VAD model loaded")
    }

    func process(samples: [Float]) -> Double {
        guard let model, let h, let c else {
            currentProbability = 0.0
            isSpeechDetected = false
            return 0.0
        }

        do {
            let inputArray = try MLMultiArray(shape: [1, NSNumber(value: samples.count)], dataType: .float32)
            for (i, sample) in samples.enumerated() {
                inputArray[i] = NSNumber(value: sample)
            }

            let srArray = try MLMultiArray(shape: [1], dataType: .int32)
            srArray[0] = NSNumber(value: Int32(Constants.Audio.sampleRate))

            let input = MLDictionaryFeatureProvider(dictionary: [
                "input": MLFeatureValue(multiArray: inputArray),
                "sr": MLFeatureValue(multiArray: srArray),
                "h": MLFeatureValue(multiArray: h),
                "c": MLFeatureValue(multiArray: c),
            ])

            let output = try model.prediction(from: input)

            if let newH = output.featureValue(for: "hn")?.multiArrayValue {
                self.h = newH
            }
            if let newC = output.featureValue(for: "cn")?.multiArrayValue {
                self.c = newC
            }

            let probability: Double
            if let outputArray = output.featureValue(for: "output")?.multiArrayValue {
                probability = Double(truncating: outputArray[0])
            } else {
                probability = 0.0
            }

            currentProbability = probability
            isSpeechDetected = probability >= Constants.Audio.vadThreshold
            return probability
        } catch {
            logger.error("VAD inference failed: \(error)")
            currentProbability = 0.0
            isSpeechDetected = false
            return 0.0
        }
    }
}
