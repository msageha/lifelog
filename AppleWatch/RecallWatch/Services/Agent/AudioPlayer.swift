import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "AudioPlayer")

actor AudioPlayer {
    private var playerNode: AVAudioPlayerNode?
    private var engine: AVAudioEngine?
    private let outputFormat: AVAudioFormat

    var volume: Float = 1.0

    init() {
        outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: Constants.Audio.sampleRate,
            channels: 1
        ) ?? AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
    }

    func setup() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)

        self.engine = engine
        self.playerNode = player

        try engine.start()
        logger.info("Audio player configured for watchOS")
    }

    func play(audioData: Data) async throws {
        guard let engine, engine.isRunning, let playerNode else {
            logger.warning("Audio engine not running, setting up")
            try setup()
            try await play(audioData: audioData)
            return
        }

        let pcmSamples = decodePCM(data: audioData)
        guard !pcmSamples.isEmpty else {
            logger.warning("No samples decoded from audio data")
            return
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(pcmSamples.count)
        ) else {
            logger.error("Failed to create PCM buffer")
            return
        }

        buffer.frameLength = AVAudioFrameCount(pcmSamples.count)
        if let channelData = buffer.floatChannelData?[0] {
            for (i, sample) in pcmSamples.enumerated() {
                channelData[i] = sample
            }
        }

        playerNode.scheduleBuffer(buffer)
        if !playerNode.isPlaying {
            playerNode.play()
        }
        logger.info("Scheduled \(pcmSamples.count) samples for playback")
    }

    func stop() {
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
        logger.info("Audio player stopped")
    }

    private func decodePCM(data: Data) -> [Float] {
        guard data.count >= MemoryLayout<Float>.size else { return [] }
        let sampleCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return [Float]() }
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
            return Array(UnsafeBufferPointer(start: floatBuffer, count: sampleCount))
        }
    }
}
