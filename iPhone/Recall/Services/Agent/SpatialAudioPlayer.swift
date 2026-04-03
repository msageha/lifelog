import AudioToolbox
import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "SpatialAudio")

enum SpatialAudioError: Error {
    case engineNotConfigured
    case decodeFailedNoFile
    case decodeFailed(OSStatus)
    case readFailed(OSStatus)
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
            throw SpatialAudioError.decodeFailedNoFile
        }
        outputFormat = format
    }

    func setup(engine: AVAudioEngine) {
        self.engine = engine
        let envNode = AVAudioEnvironmentNode()
        let player = AVAudioPlayerNode()

        engine.attach(envNode)
        engine.attach(player)

        // Connect player -> environment -> mainMixer
        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(player, to: envNode, format: outputFormat)
        engine.connect(envNode, to: engine.mainMixerNode, format: outputFormat)

        environmentNode = envNode
        playerNode = player

        updatePosition(azimuth: azimuth, distance: distance)

        logger.info("Spatial audio player configured")
    }

    func play(audioData: Data) async throws {
        guard let playerNode, let engine else {
            throw SpatialAudioError.engineNotConfigured
        }

        // Decode Opus/CAF data to PCM buffer
        let buffer = try decodeOpusData(audioData)

        if !engine.isRunning {
            try engine.start()
        }

        playerNode.scheduleBuffer(buffer) {
            logger.debug("Spatial audio buffer playback completed")
        }

        if !playerNode.isPlaying {
            playerNode.play()
        }

        playerNode.volume = volume
        logger.info("Playing spatial audio (\(audioData.count) bytes)")
    }

    func updatePosition(azimuth: Float, distance: Float) {
        self.azimuth = azimuth
        self.distance = distance

        guard let environmentNode else { return }

        // Update 3D source position using azimuth and distance
        let azimuthRadians = azimuth * .pi / 180.0
        let x = distance * sin(azimuthRadians)
        let z = -distance * cos(azimuthRadians)

        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: 0, pitch: 0, roll: 0
        )

        if let playerNode {
            playerNode.position = AVAudio3DPoint(x: x, y: 0, z: z)
        }
    }

    func updateVolume(_ newVolume: Float) {
        self.volume = newVolume
        playerNode?.volume = newVolume
    }

    // MARK: - Opus Decoding

    private func decodeOpusData(_ data: Data) throws -> AVAudioPCMBuffer {
        // Write data to a temporary file for ExtAudioFile to read
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).caf")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Open the Opus/CAF file
        var extFile: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(tempURL as CFURL, &extFile)
        guard status == noErr, let extFile else {
            throw SpatialAudioError.decodeFailed(status)
        }
        defer { ExtAudioFileDispose(extFile) }

        // Set client format to PCM Float32 for playback
        let sampleRate = Constants.Audio.sampleRate
        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )

        status = ExtAudioFileSetProperty(
            extFile,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientFormat
        )
        guard status == noErr else {
            throw SpatialAudioError.decodeFailed(status)
        }

        // Get total frame count
        var fileLengthFrames: Int64 = 0
        var propSize = UInt32(MemoryLayout<Int64>.size)
        ExtAudioFileGetProperty(
            extFile,
            kExtAudioFileProperty_FileLengthFrames,
            &propSize,
            &fileLengthFrames
        )

        let frameCount = AVAudioFrameCount(max(fileLengthFrames, Int64(sampleRate)))

        guard let pcmFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount) else {
            throw SpatialAudioError.decodeFailedNoFile
        }

        // Read decoded PCM data
        var bufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: frameCount * 4,
                mData: buffer.floatChannelData?[0]
            )
        )

        var framesRead = frameCount
        status = ExtAudioFileRead(extFile, &framesRead, &bufferList)
        guard status == noErr else {
            throw SpatialAudioError.readFailed(status)
        }

        buffer.frameLength = framesRead
        return buffer
    }
}
