import Foundation
import SwiftData

@Model
final class AgentMessage {
    var id: UUID
    var textContent: String
    var audioFilePath: String?
    var receivedAt: Date
    var isRead: Bool

    init(
        textContent: String,
        audioFilePath: String? = nil,
        receivedAt: Date = Date()
    ) {
        self.id = UUID()
        self.textContent = textContent
        self.audioFilePath = audioFilePath
        self.receivedAt = receivedAt
        self.isRead = false
    }
}
