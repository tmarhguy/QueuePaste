import Foundation

enum AppPaths {
    static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("QueuePaste", isDirectory: true)
    }

    static var databaseURL: URL {
        supportDir.appendingPathComponent("store.sqlite", isDirectory: false)
    }

    static var inboxImagesDir: URL {
        supportDir.appendingPathComponent("inbox/images", isDirectory: true)
    }

    static var inboxThumbsDir: URL {
        supportDir.appendingPathComponent("inbox/thumbs", isDirectory: true)
    }

    static func ensureSupportDirectories() throws {
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxImagesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: inboxThumbsDir, withIntermediateDirectories: true)
    }
}
