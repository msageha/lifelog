import Testing
@testable import RecallWatch

@Suite("Constants")
struct ConstantsTests {
    @Test func audioConstants() {
        #expect(Constants.Audio.sampleRate == 16000)
        #expect(Constants.Audio.vadThreshold == 0.25)
        #expect(Constants.Audio.chunkMaxDuration == 30.0)
        #expect(Constants.Audio.chunkMinDuration == 5.0)
        #expect(Constants.Audio.chunkSkipDuration == 1.0)
        #expect(Constants.Audio.preMargin == 3.0)
        #expect(Constants.Audio.postMargin == 2.0)
        #expect(Constants.Audio.opusBitrate == 48000)
    }

    @Test func storageConstants() {
        #expect(Constants.Storage.capacityLimit == 250_000_000)
    }
}
