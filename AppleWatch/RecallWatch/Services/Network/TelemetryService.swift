import Foundation
import OSLog

private let logger = Logger(subsystem: "com.recall.watch", category: "Telemetry")

actor TelemetryService {
    private var isRunning = false
    private var batchTask: Task<Void, Never>?

    private var pendingSamples: [LocationSampleDTO] = []
    private var pendingHealth: HealthSnapshotDTO?

    private let locationQueue = LocationQueue()

    func start() {
        guard !isRunning else { return }
        isRunning = true
        logger.info("Telemetry service started")
        batchTask = Task { await batchLoop() }
    }

    func stop() {
        isRunning = false
        batchTask?.cancel()
        batchTask = nil
        logger.info("Telemetry service stopped")
    }

    func addLocationSample(_ sample: LocationSampleDTO) {
        pendingSamples.append(sample)
    }

    func updateHealthSnapshot(_ snapshot: HealthSnapshotDTO) {
        pendingHealth = snapshot
    }

    private func batchLoop() {
        Task {
            while isRunning {
                do {
                    try await Task.sleep(for: .seconds(Constants.Upload.retryInterval))
                } catch {
                    break
                }
                guard isRunning else { break }
                await flushBatch()
            }
        }
    }

    private func flushBatch() async {
        // Drain any queued samples from previous failures
        var samples = pendingSamples
        pendingSamples = []

        if let queued = try? await locationQueue.dequeueAll(), !queued.isEmpty {
            samples.insert(contentsOf: queued, at: 0)
        }

        guard !samples.isEmpty || pendingHealth != nil else { return }

        let health = pendingHealth
        pendingHealth = nil

        do {
            try await sendBatch(samples: samples, health: health)
            logger.info("Telemetry batch sent: \(samples.count) samples")
        } catch {
            logger.error("Telemetry batch failed: \(error)")
            // Fallback: save samples to queue for later retry
            for sample in samples {
                try? await locationQueue.enqueue(sample)
            }
            // Restore health snapshot for next attempt
            if pendingHealth == nil {
                pendingHealth = health
            }
        }
    }

    func sendBatch(samples: [LocationSampleDTO], health: HealthSnapshotDTO?) async throws {
        guard let token = KeychainHelper.load(key: "bearerToken"),
              !token.isEmpty else {
            throw TelemetryError.noAuthToken
        }

        let payload = TelemetryBatchPayload(
            locationSamples: samples,
            healthSnapshot: health,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(payload)

        guard let baseURLString = SharedDefaults.store.string(forKey: "telemetryServerURL"),
              let baseURL = URL(string: baseURLString) else {
            throw TelemetryError.noServerURL
        }

        let url = baseURL.appendingPathComponent(Constants.Network.telemetryEndpoint)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TelemetryError.serverError(statusCode: statusCode)
        }
    }
}

private struct TelemetryBatchPayload: Codable {
    let locationSamples: [LocationSampleDTO]
    let healthSnapshot: HealthSnapshotDTO?
    let timestamp: Date
}

enum TelemetryError: Error {
    case noAuthToken
    case noServerURL
    case serverError(statusCode: Int)
}
