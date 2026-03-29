import Foundation

enum InboxItemKind: String, Codable, Sendable {
    case text
    case image
}

struct InboxRow: Identifiable, Equatable, Sendable {
    var id: String
    var createdAt: Date
    var kind: InboxItemKind
    var textContent: String?
    var imageRelPath: String?
    var thumbRelPath: String?
    var byteSize: Int64
    var pinned: Bool
    var contentHash: String
}

struct BucketRow: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var createdAt: Date
    var pinned: Bool
    var expiresAt: Date?
}

struct StagingRow: Identifiable, Equatable, Sendable {
    var id: String
    var sortIndex: Int
    var text: String
    var createdAt: Date
}
