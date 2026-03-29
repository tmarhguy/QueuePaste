import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Thread-safe SQLite access for inbox, buckets, and staging.
final class InboxDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "queuepaste.inbox.sqlite")

    init() throws {
        try AppPaths.ensureSupportDirectories()
        let path = AppPaths.databaseURL.path(percentEncoded: false)
        try queue.sync {
            guard sqlite3_open_v2(path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                throw InboxStoreError.databaseOpen
            }
            try Self.exec(db!, "PRAGMA foreign_keys = ON;")
            try migrate()
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let msg = err.map { String(cString: $0) } ?? "sqlite exec failed"
            sqlite3_free(err)
            throw InboxStoreError.sqlite(msg)
        }
    }

    private func migrate() throws {
        guard let db else { throw InboxStoreError.databaseOpen }
        var version = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                version = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)

        if version < 1 {
            try Self.exec(db, """
            CREATE TABLE IF NOT EXISTS inbox (
              id TEXT PRIMARY KEY,
              created_at REAL NOT NULL,
              kind TEXT NOT NULL,
              text_content TEXT,
              image_rel_path TEXT,
              thumb_rel_path TEXT,
              byte_size INTEGER NOT NULL DEFAULT 0,
              pinned INTEGER NOT NULL DEFAULT 0,
              content_hash TEXT NOT NULL DEFAULT ''
            );
            CREATE INDEX IF NOT EXISTS idx_inbox_created ON inbox(created_at);
            """)
            try Self.exec(db, "PRAGMA user_version = 1;")
            version = 1
        }

        if version < 2 {
            try Self.exec(db, """
            CREATE TABLE IF NOT EXISTS buckets (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at REAL NOT NULL,
              pinned INTEGER NOT NULL DEFAULT 0,
              expires_at REAL
            );
            CREATE TABLE IF NOT EXISTS bucket_items (
              bucket_id TEXT NOT NULL,
              inbox_id TEXT NOT NULL,
              added_at REAL NOT NULL,
              PRIMARY KEY (bucket_id, inbox_id),
              FOREIGN KEY (inbox_id) REFERENCES inbox(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_bucket_items_inbox ON bucket_items(inbox_id);
            """)
            try Self.exec(db, "PRAGMA user_version = 2;")
            version = 2
        }

        if version < 3 {
            try Self.exec(db, """
            CREATE TABLE IF NOT EXISTS staging_items (
              id TEXT PRIMARY KEY,
              sort_index INTEGER NOT NULL UNIQUE,
              text TEXT NOT NULL,
              created_at REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_staging_sort ON staging_items(sort_index);
            """)
            try Self.exec(db, "PRAGMA user_version = 3;")
        }
    }

    // MARK: - Inbox

    func insertInboxRow(
        id: String,
        createdAt: Date,
        kind: InboxItemKind,
        textContent: String?,
        imageRelPath: String?,
        thumbRelPath: String?,
        byteSize: Int64,
        pinned: Bool,
        contentHash: String
    ) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            let sql = """
            INSERT INTO inbox (id, created_at, kind, text_content, image_rel_path, thumb_rel_path, byte_size, pinned, content_hash)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw InboxStoreError.sqlite("prepare insert") }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, createdAt.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 3, kind.rawValue, -1, SQLITE_TRANSIENT)
            if let textContent {
                sqlite3_bind_text(stmt, 4, textContent, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            if let imageRelPath {
                sqlite3_bind_text(stmt, 5, imageRelPath, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            if let thumbRelPath {
                sqlite3_bind_text(stmt, 6, thumbRelPath, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 6)
            }
            sqlite3_bind_int64(stmt, 7, byteSize)
            sqlite3_bind_int(stmt, 8, pinned ? 1 : 0)
            sqlite3_bind_text(stmt, 9, contentHash, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw InboxStoreError.sqlite(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func deleteInbox(id: String) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "DELETE FROM inbox WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("prepare delete")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    func setInboxPinned(id: String, pinned: Bool) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "UPDATE inbox SET pinned = ? WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("prepare pin")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    func fetchInbox(
        search: String?,
        filter: InboxListFilter
    ) throws -> [InboxRow] {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var sql = "SELECT id, created_at, kind, text_content, image_rel_path, thumb_rel_path, byte_size, pinned, content_hash FROM inbox WHERE 1=1"
            switch filter {
            case .all: break
            case .text: sql += " AND kind = 'text'"
            case .images: sql += " AND kind = 'image'"
            case .pinned: sql += " AND pinned = 1"
            }
            if let search, !search.isEmpty {
                // Images are not pixel-searchable in v1 (update2 §12).
                sql += " AND kind = 'text' AND text_content LIKE ? ESCAPE '\\'"
            }
            sql += " ORDER BY created_at DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("prepare fetch")
            }
            defer { sqlite3_finalize(stmt) }
            if let search, !search.isEmpty {
                let like = "%" + InboxDatabase.escapeLike(search) + "%"
                sqlite3_bind_text(stmt, 1, like, -1, SQLITE_TRANSIENT)
            }
            var rows: [InboxRow] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
                let kindStr = String(cString: sqlite3_column_text(stmt, 2))
                let kind = InboxItemKind(rawValue: kindStr) ?? .text
                let text: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 3))
                let img: String? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 4))
                let thumb: String? = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5))
                let bytes = sqlite3_column_int64(stmt, 6)
                let pinned = sqlite3_column_int(stmt, 7) != 0
                let hash = String(cString: sqlite3_column_text(stmt, 8))
                rows.append(InboxRow(id: id, createdAt: created, kind: kind, textContent: text, imageRelPath: img, thumbRelPath: thumb, byteSize: bytes, pinned: pinned, contentHash: hash))
            }
            return rows
        }
    }

    func inboxRow(id: String) throws -> InboxRow? {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT id, created_at, kind, text_content, image_rel_path, thumb_rel_path, byte_size, pinned, content_hash FROM inbox WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("prepare one")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            let id = String(cString: sqlite3_column_text(stmt, 0))
            let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let kindStr = String(cString: sqlite3_column_text(stmt, 2))
            let kind = InboxItemKind(rawValue: kindStr) ?? .text
            let text: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 3))
            let img: String? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 4))
            let thumb: String? = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 5))
            let bytes = sqlite3_column_int64(stmt, 6)
            let pinned = sqlite3_column_int(stmt, 7) != 0
            let hash = String(cString: sqlite3_column_text(stmt, 8))
            return InboxRow(id: id, createdAt: created, kind: kind, textContent: text, imageRelPath: img, thumbRelPath: thumb, byteSize: bytes, pinned: pinned, contentHash: hash)
        }
    }
    
    /// Check if an inbox item with the given content hash already exists
    func hasInboxItemWithHash(_ hash: String) throws -> Bool {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM inbox WHERE content_hash = ?;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("prepare hash check")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, hash, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
            let count = sqlite3_column_int(stmt, 0)
            return count > 0
        }
    }

    func inboxTotals() throws -> (count: Int, totalBytes: Int64, pinnedCount: Int, pinnedBytes: Int64) {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var totalCount = 0
            var totalBytes: Int64 = 0
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT COUNT(*), IFNULL(SUM(byte_size),0) FROM inbox;", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    totalCount = Int(sqlite3_column_int(stmt, 0))
                    totalBytes = sqlite3_column_int64(stmt, 1)
                }
            }
            sqlite3_finalize(stmt)
            var pinnedCount = 0
            var pinnedBytes: Int64 = 0
            if sqlite3_prepare_v2(db, "SELECT COUNT(*), IFNULL(SUM(byte_size),0) FROM inbox WHERE pinned = 1;", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    pinnedCount = Int(sqlite3_column_int(stmt, 0))
                    pinnedBytes = sqlite3_column_int64(stmt, 1)
                }
            }
            sqlite3_finalize(stmt)
            return (totalCount, totalBytes, pinnedCount, pinnedBytes)
        }
    }

    /// Oldest unpinned rows first (for eviction).
    func inboxUnpinnedOldestIds() throws -> [String] {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT id FROM inbox WHERE pinned = 0 ORDER BY created_at ASC;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("prepare eviction ids")
            }
            defer { sqlite3_finalize(stmt) }
            var ids: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                ids.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            return ids
        }
    }

    // MARK: - Buckets

    func insertBucket(id: String, name: String, createdAt: Date, pinned: Bool, expiresAt: Date?) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            let sql = "INSERT INTO buckets (id, name, created_at, pinned, expires_at) VALUES (?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw InboxStoreError.sqlite("insert bucket") }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, createdAt.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 4, pinned ? 1 : 0)
            if let expiresAt {
                sqlite3_bind_double(stmt, 5, expiresAt.timeIntervalSince1970)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            _ = sqlite3_step(stmt)
        }
    }

    func deleteBucket(id: String) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "DELETE FROM bucket_items WHERE bucket_id = ?;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("delete bucket items")
            }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)

            guard sqlite3_prepare_v2(db, "DELETE FROM buckets WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("delete bucket")
            }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    func deleteExpiredBuckets(now: Date) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            let ts = now.timeIntervalSince1970
            let sql = """
            DELETE FROM bucket_items WHERE bucket_id IN (
              SELECT id FROM buckets WHERE pinned = 0 AND expires_at IS NOT NULL AND expires_at < \(ts)
            );
            DELETE FROM buckets WHERE pinned = 0 AND expires_at IS NOT NULL AND expires_at < \(ts);
            """
            try Self.exec(db, sql)
        }
    }

    func fetchBuckets() throws -> [BucketRow] {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT id, name, created_at, pinned, expires_at FROM buckets ORDER BY created_at DESC;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("fetch buckets")
            }
            defer { sqlite3_finalize(stmt) }
            var rows: [BucketRow] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                let pinned = sqlite3_column_int(stmt, 3) != 0
                let exp: Date? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
                rows.append(BucketRow(id: id, name: name, createdAt: created, pinned: pinned, expiresAt: exp))
            }
            return rows
        }
    }

    func setBucketPinned(id: String, pinned: Bool) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            let sql: String
            if pinned {
                sql = "UPDATE buckets SET pinned = 1, expires_at = NULL WHERE id = ?;"
            } else {
                sql = "UPDATE buckets SET pinned = 0, expires_at = ? WHERE id = ?;"
            }
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw InboxStoreError.sqlite("pin bucket") }
            defer { sqlite3_finalize(stmt) }
            if pinned {
                sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            } else {
                let exp = Date().addingTimeInterval(86_400).timeIntervalSince1970
                sqlite3_bind_double(stmt, 1, exp)
                sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            }
            _ = sqlite3_step(stmt)
        }
    }

    func addToBucket(bucketId: String, inboxId: String, addedAt: Date) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            let sql = "INSERT OR REPLACE INTO bucket_items (bucket_id, inbox_id, added_at) VALUES (?, ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw InboxStoreError.sqlite("bucket add") }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, bucketId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, inboxId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, addedAt.timeIntervalSince1970)
            _ = sqlite3_step(stmt)
        }
    }

    func inboxIdsInBucket(bucketId: String) throws -> [String] {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT inbox_id FROM bucket_items WHERE bucket_id = ? ORDER BY added_at DESC;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("bucket members")
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, bucketId, -1, SQLITE_TRANSIENT)
            var ids: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                ids.append(String(cString: sqlite3_column_text(stmt, 0)))
            }
            return ids
        }
    }

    // MARK: - Staging

    func nextStagingSortIndex() throws -> Int {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT IFNULL(MAX(sort_index), -1) + 1 FROM staging_items;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("staging max")
            }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }
    }

    func insertStaging(id: String, sortIndex: Int, text: String, createdAt: Date) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            let sql = "INSERT INTO staging_items (id, sort_index, text, created_at) VALUES (?, ?, ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw InboxStoreError.sqlite("staging insert") }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(sortIndex))
            sqlite3_bind_text(stmt, 3, text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 4, createdAt.timeIntervalSince1970)
            _ = sqlite3_step(stmt)
        }
    }

    func deleteStaging(id: String) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "DELETE FROM staging_items WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    func clearStaging() throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            try Self.exec(db, "DELETE FROM staging_items;")
        }
    }

    func fetchStaging() throws -> [StagingRow] {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT id, sort_index, text, created_at FROM staging_items ORDER BY sort_index ASC;", -1, &stmt, nil) == SQLITE_OK else {
                throw InboxStoreError.sqlite("staging fetch")
            }
            defer { sqlite3_finalize(stmt) }
            var rows: [StagingRow] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let idx = Int(sqlite3_column_int(stmt, 1))
                let text = String(cString: sqlite3_column_text(stmt, 2))
                let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
                rows.append(StagingRow(id: id, sortIndex: idx, text: text, createdAt: created))
            }
            return rows
        }
    }

    func updateStagingSort(id: String, sortIndex: Int) throws {
        try queue.sync {
            guard let db else { throw InboxStoreError.databaseOpen }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "UPDATE staging_items SET sort_index = ? WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(sortIndex))
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    private static func escapeLike(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}

enum InboxListFilter: String, CaseIterable, Sendable {
    case all
    case text
    case images
    case pinned
}

enum InboxStoreError: Error {
    case databaseOpen
    case sqlite(String)
    case imageWrite
    case pinsExceedLimits
}
