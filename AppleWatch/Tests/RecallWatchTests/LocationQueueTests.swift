import Testing
@testable import RecallWatch

@Suite("LocationQueue", .serialized)
struct LocationQueueTests {
    private func makeSample(latitude: Double = 35.0) -> LocationSampleDTO {
        LocationSampleDTO(
            latitude: latitude,
            longitude: 139.0,
            altitude: 10.0,
            accuracy: 5.0,
            speed: 0.0,
            timestamp: Date(),
            motionActivity: "walking",
            motionConfidence: "high"
        )
    }

    @Test func enqueueAndDequeueAllFIFO() async throws {
        let queue = LocationQueue()
        _ = try? await queue.dequeueAll() // ensure clean state
        defer { _ = try? await queue.dequeueAll() }

        try await queue.enqueue(makeSample(latitude: 35.0))
        try await queue.enqueue(makeSample(latitude: 36.0))
        try await queue.enqueue(makeSample(latitude: 37.0))

        let items = try await queue.dequeueAll()
        #expect(items.count == 3)
        #expect(items[0].latitude == 35.0)
        #expect(items[1].latitude == 36.0)
        #expect(items[2].latitude == 37.0)
    }

    @Test func dequeueAllEmptyQueueReturnsEmptyArray() async throws {
        let queue = LocationQueue()
        _ = try? await queue.dequeueAll() // ensure clean state

        let items = try await queue.dequeueAll()
        #expect(items.isEmpty)
    }

    @Test func persistenceAcrossInstances() async throws {
        let queue1 = LocationQueue()
        _ = try? await queue1.dequeueAll() // ensure clean state
        try await queue1.enqueue(makeSample(latitude: 35.0))

        let queue2 = LocationQueue()
        let items = try await queue2.dequeueAll()
        #expect(items.count == 1)
        #expect(items[0].latitude == 35.0)
    }

    @Test func dequeueAllClearsQueue() async throws {
        let queue = LocationQueue()
        _ = try? await queue.dequeueAll() // ensure clean state
        try await queue.enqueue(makeSample())

        _ = try await queue.dequeueAll()
        let items = try await queue.dequeueAll()
        #expect(items.isEmpty)
    }
}
