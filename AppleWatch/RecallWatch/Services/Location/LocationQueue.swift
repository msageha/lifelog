import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "LocationQueue")

actor LocationQueue {
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("location_queue.json")
    }

    func enqueue(_ sample: LocationSampleDTO) throws {
        var items = load()
        items.append(sample)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
        logger.debug("Enqueued location sample, queue size: \(items.count)")
    }

    func dequeueAll() throws -> [LocationSampleDTO] {
        let items = load()
        try? FileManager.default.removeItem(at: fileURL)
        return items
    }

    private func load() -> [LocationSampleDTO] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([LocationSampleDTO].self, from: data)) ?? []
    }
}

struct LocationSampleDTO: Codable, Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let accuracy: Double
    let speed: Double
    let timestamp: Date
    let motionActivity: String
    let motionConfidence: String
}
