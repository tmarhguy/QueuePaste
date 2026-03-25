import Foundation

struct PersistedQueueSession: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var savedAt: Date
    var items: [QueueItem]
    var pointer: Int
    var state: QueueState
    var skippedItems: [QueueItem]
    var inputText: String

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        savedAt: Date = Date(),
        items: [QueueItem],
        pointer: Int,
        state: QueueState,
        skippedItems: [QueueItem],
        inputText: String
    ) {
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
        self.items = items
        self.pointer = pointer
        self.state = state
        self.skippedItems = skippedItems
        self.inputText = inputText
    }

    /// Whether this snapshot should offer “resume” on launch (non-empty queue and meaningful progress or non-idle state).
    var isResumable: Bool {
        guard !items.isEmpty else { return false }
        if pointer > 0 { return true }
        switch state {
        case .ready, .active, .paused, .complete: return true
        case .idle: return false
        }
    }
}
