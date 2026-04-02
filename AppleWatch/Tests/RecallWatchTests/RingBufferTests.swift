import Testing
@testable import RecallWatch

@Suite("RingBuffer")
struct RingBufferTests {
    @Test func writeAndRead() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.write(1)
        buffer.write(2)
        buffer.write(3)

        #expect(buffer.count == 3)
        #expect(buffer.isFull)
        #expect(buffer.read() == 1)
        #expect(buffer.read() == 2)
        #expect(buffer.read() == 3)
        #expect(buffer.isEmpty)
    }

    @Test func overwriteOldest() {
        var buffer = RingBuffer<Int>(capacity: 2)
        buffer.write(1)
        buffer.write(2)
        buffer.write(3) // overwrites 1

        #expect(buffer.count == 2)
        #expect(buffer.read() == 2)
        #expect(buffer.read() == 3)
    }

    @Test func readAll() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.write(10)
        buffer.write(20)
        buffer.write(30)

        let all = buffer.readAll()
        #expect(all == [10, 20, 30])
        #expect(buffer.isEmpty)
    }
}
