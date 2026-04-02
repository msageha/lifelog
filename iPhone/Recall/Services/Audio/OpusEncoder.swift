import AudioToolbox
import AVFoundation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall", category: "OpusEncoder")

enum OpusEncoderError: Error {
    case invalidInputFormat
    case invalidOutputFormat
    case fileCreationFailed(OSStatus)
    case clientFormatFailed(OSStatus)
    case encodingFailed(OSStatus)
}

actor OpusEncoder {
    private let outputDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        outputDirectory = docs.appendingPathComponent(Constants.Storage.chunksDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func encode(samples: [Float], startedAt: Date) async throws -> URL {
        let formatter = ISO8601DateFormatter()
        let filename = "\(formatter.string(from: startedAt)).caf"
        let outputURL = outputDirectory.appendingPathComponent(filename)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        let sampleRate = Constants.Audio.sampleRate

        // Output format: Opus in CAF container
        var outputASBD = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(sampleRate * 0.02), // 20 ms frames → 320 at 16 kHz
            mBytesPerFrame: 0,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 0,
            mReserved: 0
        )

        // Client (input) format: PCM Float32 mono
        var clientASBD = AudioStreamBasicDescription(
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

        // Create ExtAudioFile for Opus/CAF output
        var extFile: ExtAudioFileRef?
        var status = ExtAudioFileCreateWithURL(
            outputURL as CFURL,
            kAudioFileCAFType,
            &outputASBD,
            nil, // channel layout
            AudioFileFlags.eraseFile.rawValue,
            &extFile
        )
        guard status == noErr, let extFile else {
            throw OpusEncoderError.fileCreationFailed(status)
        }
        defer { ExtAudioFileDispose(extFile) }

        // Set client data format (PCM Float32 input)
        status = ExtAudioFileSetProperty(
            extFile,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &clientASBD
        )
        guard status == noErr else {
            throw OpusEncoderError.clientFormatFailed(status)
        }

        // Configure encoder bitrate
        configureEncoderBitrate(extFile: extFile)

        // Write PCM samples – ExtAudioFile handles Opus encoding internally
        try writeSamples(samples, to: extFile, sampleRate: sampleRate)

        logger.info("Encoded chunk to \(outputURL.lastPathComponent) (\(samples.count) samples)")
        return outputURL
    }

    // MARK: - Private

    private func configureEncoderBitrate(extFile: ExtAudioFileRef) {
        var converterRef: AudioConverterRef?
        var size = UInt32(MemoryLayout<AudioConverterRef>.size)
        let getStatus = ExtAudioFileGetProperty(
            extFile,
            kExtAudioFileProperty_AudioConverter,
            &size,
            &converterRef
        )
        guard getStatus == noErr, let converter = converterRef else { return }

        var bitrate = UInt32(Constants.Audio.opusBitrate)
        AudioConverterSetProperty(
            converter,
            kAudioConverterEncodeBitRate,
            UInt32(MemoryLayout<UInt32>.size),
            &bitrate
        )
    }

    private func writeSamples(_ samples: [Float], to extFile: ExtAudioFileRef, sampleRate: Double) throws {
        let batchSize = Int(sampleRate) // Write 1 second at a time
        var offset = 0

        try samples.withUnsafeBufferPointer { basePtr in
            while offset < samples.count {
                let remaining = samples.count - offset
                let framesToWrite = min(batchSize, remaining)

                var bufferList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(framesToWrite * MemoryLayout<Float>.size),
                        mData: UnsafeMutableRawPointer(
                            mutating: basePtr.baseAddress!.advanced(by: offset)
                        )
                    )
                )

                let writeStatus = ExtAudioFileWrite(extFile, UInt32(framesToWrite), &bufferList)
                guard writeStatus == noErr else {
                    throw OpusEncoderError.encodingFailed(writeStatus)
                }

                offset += framesToWrite
            }
        }
    }
}
