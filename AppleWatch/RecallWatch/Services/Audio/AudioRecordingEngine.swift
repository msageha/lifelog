import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "AudioRecordingEngine")

actor AudioRecordingEngine {
    private var engine: AVAudioEngine?
    private var isRunning = false
    private var ringBuffer: RingBuffer<Float>
    private let vadProcessor: VADProcessor
    private let chunkManager: ChunkManager
    private let watchdog: EngineWatchdog
    private var wasSpeechDetected = false

    /// Pre-margin sample count: 3 seconds at 16kHz
    private let preMarginCapacity: Int

    init(vadProcessor: VADProcessor, chunkManager: ChunkManager, watchdog: EngineWatchdog) {
        self.vadProcessor = vadProcessor
        self.chunkManager = chunkManager
        self.watchdog = watchdog
        self.preMarginCapacity = Int(Constants.Audio.preMargin * Constants.Audio.sampleRate)
        self.ringBuffer = RingBuffer<Float>(capacity: preMarginCapacity)
    }

    func start() throws {
        guard !isRunning else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Constants.Audio.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioEngineError.invalidFormat
        }

        inputNode.installTap(onBus: 0, bufferSize: 1600, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let frameCount = Int(buffer.frameLength)
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            Task {
                await self.handleAudioBuffer(samples)
            }
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
        wasSpeechDetected = false
        logger.info("Audio engine stopped")
    }

    // MARK: - Private

    private func handleAudioBuffer(_ samples: [Float]) async {
        await watchdog.updateWriteTime()

        // Write every sample into the ring buffer (rolling pre-margin window)
        for sample in samples {
            ringBuffer.write(sample)
        }

        // Run VAD inference (each tap buffer ≈ 100 ms = 1600 samples at 16 kHz)
        let probability = await vadProcessor.process(samples: samples)
        let isSpeech = probability >= Constants.Audio.vadThreshold

        if isSpeech && !wasSpeechDetected {
            // Speech onset – snapshot pre-margin from ring buffer
            let preMarginSamples = snapshotRingBuffer()
            await chunkManager.onSpeechStart(preMarginSamples: preMarginSamples)
        } else if !isSpeech && wasSpeechDetected {
            await chunkManager.onSpeechEnd()
        }

        wasSpeechDetected = isSpeech

        // Forward samples to ChunkManager while a chunk is being recorded
        await chunkManager.appendSamples(samples)
    }

    /// Non-destructive read of ring buffer contents for pre-margin.
    private func snapshotRingBuffer() -> [Float] {
        var copy = ringBuffer
        return copy.readAll()
    }
}

enum AudioEngineError: Error {
    case invalidFormat
}
