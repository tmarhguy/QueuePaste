import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class InboxStore {
    static let shared = InboxStore()

    private let db: InboxDatabase
    private var lastCaptureHash: String?

    private init() {
        do {
            db = try InboxDatabase()
        } catch {
            fatalError("Inbox database failed: \(error)")
        }
    }

    // MARK: - Capture

    enum CaptureResult: Equatable {
        case skippedDuplicate
        case skippedEmpty
        case skippedPinsFull(String)
        case captured
    }

    /// Captures current general pasteboard into inbox (manual or passive).
    func captureFromPasteboard(isManual: Bool) throws -> CaptureResult {
        let pb = NSPasteboard.general

        if !isManual,
           let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           AppSettings.shared.ignoredBundleIds.contains(bundle) {
            return .skippedDuplicate
        }

        let totals = try db.inboxTotals()
        if totals.pinnedCount >= AppSettings.maxInboxItems || totals.pinnedBytes >= Int64(AppSettings.maxInboxBytes) {
            let msg = "Pinned items exceed inbox limits. Unpin or delete items to resume capture."
            return .skippedPinsFull(msg)
        }

        if let text = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            let hash = Self.hashString(text)
            
            // Always check against lastCaptureHash to prevent immediate duplicates
            if hash == lastCaptureHash { return .skippedDuplicate }
            
            // Also check if this exact content already exists in the database (regardless of deduplication setting)
            if try db.hasInboxItemWithHash(hash) {
                lastCaptureHash = hash
                return .skippedDuplicate
            }
            
            lastCaptureHash = hash
            let id = UUID().uuidString
            let bytes = Int64(text.utf8.count)
            try db.insertInboxRow(
                id: id,
                createdAt: .now,
                kind: .text,
                textContent: text,
                imageRelPath: nil,
                thumbRelPath: nil,
                byteSize: bytes,
                pinned: false,
                contentHash: hash
            )
            try evictUntilUnderLimits()
            return .captured
        }

        if let image = NSImage(pasteboard: pb) ?? imageFromPasteboard(pb),
           let pngData = image.pngData() {
            let hash = Self.hashData(pngData)
            
            // Always check against lastCaptureHash to prevent immediate duplicates
            if hash == lastCaptureHash { return .skippedDuplicate }
            
            // Also check if this exact content already exists in the database
            if try db.hasInboxItemWithHash(hash) {
                lastCaptureHash = hash
                return .skippedDuplicate
            }
            
            lastCaptureHash = hash
            let id = UUID().uuidString
            let fileName = "\(id).png"
            let thumbName = "\(id)_thumb.jpg"
            let imgURL = AppPaths.inboxImagesDir.appendingPathComponent(fileName)
            let thumbURL = AppPaths.inboxThumbsDir.appendingPathComponent(thumbName)
            try pngData.write(to: imgURL, options: .atomic)
            let thumbData = try Self.makeThumbnailJPEG(from: image)
            try thumbData.write(to: thumbURL, options: .atomic)
            let bytes = Int64((try? FileManager.default.attributesOfItem(atPath: imgURL.path)[.size] as? Int) ?? pngData.count)
            try db.insertInboxRow(
                id: id,
                createdAt: .now,
                kind: .image,
                textContent: nil,
                imageRelPath: fileName,
                thumbRelPath: thumbName,
                byteSize: bytes,
                pinned: false,
                contentHash: hash
            )
            try evictUntilUnderLimits()
            return .captured
        }

        return .skippedEmpty
    }

    func addTextItem(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hash = Self.hashString(trimmed)
        let id = UUID().uuidString
        let bytes = Int64(trimmed.utf8.count)
        try db.insertInboxRow(
            id: id, createdAt: .now, kind: .text, textContent: trimmed,
            imageRelPath: nil, thumbRelPath: nil, byteSize: bytes,
            pinned: false, contentHash: hash
        )
        try evictUntilUnderLimits()
    }

    func addImageItem(_ image: NSImage) throws {
        guard let pngData = image.pngData() else { return }
        let hash = Self.hashData(pngData)
        let id = UUID().uuidString
        let fileName = "\(id).png"
        let thumbName = "\(id)_thumb.jpg"
        let imgURL = AppPaths.inboxImagesDir.appendingPathComponent(fileName)
        let thumbURL = AppPaths.inboxThumbsDir.appendingPathComponent(thumbName)
        try pngData.write(to: imgURL, options: .atomic)
        let thumbData = try Self.makeThumbnailJPEG(from: image)
        try thumbData.write(to: thumbURL, options: .atomic)
        let bytes = Int64(pngData.count)
        try db.insertInboxRow(
            id: id, createdAt: .now, kind: .image, textContent: nil,
            imageRelPath: fileName, thumbRelPath: thumbName, byteSize: bytes,
            pinned: false, contentHash: hash
        )
        try evictUntilUnderLimits()
    }

    func copyInboxItemToPasteboard(id: String) throws {
        guard let row = try db.inboxRow(id: id) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch row.kind {
        case .text:
            if let t = row.textContent {
                pasteboard.setString(t, forType: .string)
            }
        case .image:
            if let rel = row.imageRelPath {
                let url = AppPaths.inboxImagesDir.appendingPathComponent(rel)
                if let img = NSImage(contentsOf: url) {
                    pasteboard.writeObjects([img])
                }
            }
        }
    }

    func deleteInboxItem(id: String) throws {
        if let row = try db.inboxRow(id: id) {
            if let rel = row.imageRelPath {
                try? FileManager.default.removeItem(at: AppPaths.inboxImagesDir.appendingPathComponent(rel))
            }
            if let th = row.thumbRelPath {
                try? FileManager.default.removeItem(at: AppPaths.inboxThumbsDir.appendingPathComponent(th))
            }
        }
        try db.deleteInbox(id: id)
    }

    func setPinned(id: String, pinned: Bool) throws {
        try db.setInboxPinned(id: id, pinned: pinned)
    }

    func inboxRows(search: String?, filter: InboxListFilter) throws -> [InboxRow] {
        try db.fetchInbox(search: search, filter: filter)
    }

    func inboxRow(id: String) throws -> InboxRow? {
        try db.inboxRow(id: id)
    }

    func inboxTotals() throws -> (count: Int, totalBytes: Int64, pinnedCount: Int, pinnedBytes: Int64) {
        try db.inboxTotals()
    }

    func imageFileURL(for row: InboxRow) -> URL? {
        guard let rel = row.imageRelPath else { return nil }
        return AppPaths.inboxImagesDir.appendingPathComponent(rel)
    }

    func thumbFileURL(for row: InboxRow) -> URL? {
        guard let rel = row.thumbRelPath else { return nil }
        return AppPaths.inboxThumbsDir.appendingPathComponent(rel)
    }

    // MARK: - Retention

    private func evictUntilUnderLimits() throws {
        var totals = try db.inboxTotals()
        while totals.count > AppSettings.maxInboxItems || totals.totalBytes > Int64(AppSettings.maxInboxBytes) {
            let candidates = try db.inboxUnpinnedOldestIds()
            guard let victim = candidates.first else { break }
            try deleteInboxItem(id: victim)
            totals = try db.inboxTotals()
        }
    }

    // MARK: - Buckets

    func pruneExpiredBuckets() throws {
        try db.deleteExpiredBuckets(now: .now)
    }

    func allBuckets() throws -> [BucketRow] {
        try pruneExpiredBuckets()
        return try db.fetchBuckets()
    }

    func createBucket(named name: String) throws -> BucketRow {
        let id = UUID().uuidString
        let exp = Date().addingTimeInterval(86_400)
        try db.insertBucket(id: id, name: name, createdAt: .now, pinned: false, expiresAt: exp)
        return BucketRow(id: id, name: name, createdAt: .now, pinned: false, expiresAt: exp)
    }

    func deleteBucket(id: String) throws {
        try db.deleteBucket(id: id)
    }

    func setBucketPinned(id: String, pinned: Bool) throws {
        try db.setBucketPinned(id: id, pinned: pinned)
    }

    func addInboxItem(_ inboxId: String, toBucket bucketId: String) throws {
        try db.addToBucket(bucketId: bucketId, inboxId: inboxId, addedAt: .now)
    }

    func inboxIds(inBucket bucketId: String) throws -> [String] {
        try db.inboxIdsInBucket(bucketId: bucketId)
    }

    // MARK: - Staging

    func stagingRows() throws -> [StagingRow] {
        try db.fetchStaging()
    }

    func addStagingText(_ text: String) throws {
        let id = UUID().uuidString
        let idx = try db.nextStagingSortIndex()
        try db.insertStaging(id: id, sortIndex: idx, text: text, createdAt: .now)
    }

    func deleteStaging(id: String) throws {
        try db.deleteStaging(id: id)
    }

    func clearStaging() throws {
        try db.clearStaging()
    }

    func saveStagingOrder(_ rows: [StagingRow]) throws {
        try db.clearStaging()
        for (i, r) in rows.enumerated() {
            try db.insertStaging(id: r.id, sortIndex: i, text: r.text, createdAt: r.createdAt)
        }
    }

    func applyTransformToStaging(trim: Bool, regexPattern: String, replacement: String, prefix: String, suffix: String) throws {
        var rows = try stagingRows()
        let rx: NSRegularExpression? = {
            guard !regexPattern.isEmpty else { return nil }
            return try? NSRegularExpression(pattern: regexPattern, options: [])
        }()
        for i in rows.indices {
            var t = rows[i].text
            if trim {
                t = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let rx {
                let range = NSRange(t.startIndex..., in: t)
                t = rx.stringByReplacingMatches(in: t, options: [], range: range, withTemplate: replacement)
            }
            t = prefix + t + suffix
            rows[i].text = t
        }
        try saveStagingOrder(rows)
    }

    // MARK: - Helpers

    private static func hashString(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func hashData(_ d: Data) -> String {
        let digest = SHA256.hash(data: d)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func makeThumbnailJPEG(from image: NSImage) throws -> Data {
        let maxSide: CGFloat = 160
        let srcSize = image.size
        guard srcSize.width > 0, srcSize.height > 0 else { return Data() }
        let scale = min(1, maxSide / max(srcSize.width, srcSize.height))
        let outSize = NSSize(width: srcSize.width * scale, height: srcSize.height * scale)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(outSize.width)),
            pixelsHigh: max(1, Int(outSize.height)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = outSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: outSize), from: NSRect(origin: .zero, size: srcSize), operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) else {
            throw InboxStoreError.imageWrite
        }
        return data
    }

    private func imageFromPasteboard(_ pb: NSPasteboard) -> NSImage? {
        if let data = pb.data(forType: .tiff), let img = NSImage(data: data) { return img }
        if let data = pb.data(forType: .png), let img = NSImage(data: data) { return img }
        return nil
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        return data
    }
}
