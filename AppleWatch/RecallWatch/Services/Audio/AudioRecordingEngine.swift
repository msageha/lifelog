import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "AudioRecordingEngine")

actor AudioRecordingEngine {
    private var engine: AVAudioEngine?
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.Audio.sampleRate,
            channels: 1,
            interleaved: false
        )!

        inputNode.installTap(onBus: 0, bufferSize: 1600, format: format) { buffer, time in
            // TODO: Feed buffer to VADProcessor and RingBuffer
        }

        try engine.start()
        self.engine = engine
        isRunning = true
        logger.info("Audio engine started")
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isRunning = false
        logger.info("Audio engine stopped")
    }
}
