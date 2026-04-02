import Testing
@testable import Recall

@Suite("VADProcessor")
struct VADProcessorTests {
    @Test func processSamplesWithoutModelReturnsFallback() async {
        let vad = VADProcessor()
        let result = await vad.process(samples: [0.1, 0.2, 0.3])
        #expect(result == 0.0)
    }

    @Test func processEmptySamplesDoesNotCrash() async {
        let vad = VADProcessor()
        let result = await vad.process(samples: [])
        #expect(result == 0.0)
    }

    @Test func processUpdatesCurrentProbability() async {
        let vad = VADProcessor()
        _ = await vad.process(samples: [0.5, 0.5])
        let prob = await vad.currentProbability
        #expect(prob == 0.0)
    }

    @Test func processUpdatesSpeechDetected() async {
        let vad = VADProcessor()
        _ = await vad.process(samples: [0.5, 0.5])
        // With no model, probability is 0.0 which is below vadThreshold (0.25)
        let detected = await vad.isSpeechDetected
        #expect(detected == false)
    }
}
