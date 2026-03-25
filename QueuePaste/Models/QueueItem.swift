import Foundation

struct QueueItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var isSkipped: Bool

    init(id: UUID = UUID(), text: String, isSkipped: Bool = false) {
        self.id = id
        self.text = text
        self.isSkipped = isSkipped
    }
}
