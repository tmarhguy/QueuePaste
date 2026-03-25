import Foundation

struct QueueSessionStore: Sendable {
    private let fileManager: FileManager
    private let fileURL: URL

    nonisolated init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("QueuePaste", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("session.json", isDirectory: false)
    }

    func load() -> PersistedQueueSession? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var session = try decoder.decode(PersistedQueueSession.self, from: data)
            if session.schemaVersion != PersistedQueueSession.currentSchemaVersion {
                return nil
            }
            session.pointer = clampPointer(session.pointer, itemCount: session.items.count)
            return session
        } catch {
            return nil
        }
    }

    func save(_ session: PersistedQueueSession) throws {
        var toWrite = session
        toWrite.pointer = clampPointer(toWrite.pointer, itemCount: toWrite.items.count)
        let dir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(toWrite)
        try data.write(to: fileURL, options: .atomic)
    }

    func delete() {
        try? fileManager.removeItem(at: fileURL)
    }

    /// Allows `pointer == itemCount` (one past last) for a completed queue.
    private func clampPointer(_ pointer: Int, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(max(0, pointer), itemCount)
    }
}
