import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "SpatialAudio")

enum SpatialAudioPlayerError: Error {
    case audioFormatCreationFailed
}

actor SpatialAudioPlayer {
    private var engine: AVAudioEngine?
    private var environmentNode: AVAudioEnvironmentNode?
    private var playerNode: AVAudioPlayerNode?
    private let outputFormat: AVAudioFormat

    var azimuth: Float = 0.0
    var distance: Float = 1.0
    var volume: Float = 1.0

    init() throws {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: Constants.Audio.sampleRate,
            channels: 1
        ) ?? AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1) else {
            throw SpatialAudioPlayerError.audioFormatCreationFailed
        }
        outputFormat = format
    }

    func setup() throws {
        let engine = AVAudioEngine()
        let envNode = AVAudioEnvironmentNode()
        let player = AVAudioPlayerNode()

        engine.attach(envNode)
        engine.attach(player)

        // Connect player -> environment -> mainMixer
        engine.connect(player, to: envNode, format: outputFormat)
        engine.connect(envNode, to: engine.mainMixerNode, format: nil)

        self.engine = engine
        self.environmentNode = envNode
        self.playerNode = player

        try engine.start()
        logger.info("Spatial audio engine started")
    }

    func play(audioData: Data) async throws {
        if engine == nil || !(engine?.isRunning ?? false) || playerNode == nil {
            logger.warning("Audio engine not running, setting up")
            try setup()
        }

        guard let engine, engine.isRunning, let playerNode else {
            logger.error("Audio engine setup failed")
            return
        }

        // Decode Opus data to PCM samples
        let pcmSamples = decodeOpus(data: audioData)
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
        logger.info("Scheduled \(pcmSamples.count) samples for spatial playback")
    }

    func updatePosition(azimuth: Float, distance: Float) {
        self.azimuth = azimuth
        self.distance = distance

        guard let environmentNode else { return }
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)

        // Convert azimuth (degrees) and distance to 3D position
        let radians = azimuth * .pi / 180.0
        let x = distance * sin(radians)
        let z = -distance * cos(radians)

        if let playerNode {
            playerNode.position = AVAudio3DPoint(x: x, y: 0, z: z)
        }
    }

    func stop() {
        playerNode?.stop()
        engine?.stop()
        engine = nil
        environmentNode = nil
        playerNode = nil
        logger.info("Spatial audio player stopped")
    }

    // MARK: - Private

    private func decodeOpus(data: Data) -> [Float] {
        // Opus decoding requires a third-party library (e.g., libopus).
        // For now, treat incoming data as raw PCM float32 samples as a fallback.
        guard data.count >= MemoryLayout<Float>.size else { return [] }
        let sampleCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return [Float]() }
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
            return Array(UnsafeBufferPointer(start: floatBuffer, count: sampleCount))
        }
    }
}
