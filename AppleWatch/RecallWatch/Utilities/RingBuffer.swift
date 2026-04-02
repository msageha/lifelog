import Foundation

struct RingBuffer<Element>: Sendable where Element: Sendable {
    private var buffer: [Element?]
    private var writeIndex = 0
    private var readIndex = 0
    private(set) var count = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    mutating func write(_ element: Element) {
        buffer[writeIndex % capacity] = element
        writeIndex += 1
        if count < capacity {
            count += 1
        } else {
            readIndex += 1
        }
    }

    mutating func read() -> Element? {
        guard count > 0 else { return nil }
        let element = buffer[readIndex % capacity]
        readIndex += 1
        count -= 1
        return element
    }

    mutating func readAll() -> [Element] {
        var result: [Element] = []
        result.reserveCapacity(count)
        while count > 0 {
            if let element = read() {
                result.append(element)
            }
        }
        return result
    }

    var isFull: Bool { count == capacity }
    var isEmpty: Bool { count == 0 }
}
