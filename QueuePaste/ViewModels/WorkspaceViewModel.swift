import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case dump
    case inbox
    case buckets
    case staging
    case queue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dump: return "Dump"
        case .inbox: return "Inbox"
        case .buckets: return "Buckets"
        case .staging: return "Staging"
        case .queue: return "Queue"
        }
    }
}

@Observable
@MainActor
final class WorkspaceViewModel {

    /// Set from `ContentView.onAppear` so global hotkeys can reach the active workspace model.
    private static weak var registeredInstance: WorkspaceViewModel?
    static func registerForGlobalHotkeys(_ vm: WorkspaceViewModel) {
        registeredInstance = vm
    }
    private static var hotkeyTarget: WorkspaceViewModel? { registeredInstance }

    var isVisible = false
    var selectedTab: WorkspaceTab = .dump
    
    // Dump view state
    var dumpRows: [InboxRow] = []
    var dumpAutoScroll = true
    var dumpShowImages = true
    var dumpCompactMode = false

    var searchText = ""
    var inboxFilter: InboxListFilter = .all
    var inboxRows: [InboxRow] = []
    var selectedInboxId: String?

    var multiSelectedInboxIds: Set<String> = []
    var inboxBatchMode = false

    var buckets: [BucketRow] = []
    var selectedBucketId: String?
    var bucketInboxRows: [InboxRow] = []

    var stagingRows: [StagingRow] = []
    var selectedStagingId: String?

    var toastMessage: String?
    private var toastTask: Task<Void, Never>?

    var showPinsFullBanner = false
    var pinsFullText = ""

    var showSendQueueConfirm = false
    var pendingStagingExport: [String] = []

    var showFirstRunCaptureInfo = false

    // Transform (staging)
    var transformTrim = true
    var transformRegex = ""
    var transformReplacement = ""
    var transformPrefix = ""
    var transformSuffix = ""

    // Capture settings (inline)
    var passiveCaptureEnabled: Bool {
        get { AppSettings.shared.passiveCaptureEnabled }
        set { AppSettings.shared.passiveCaptureEnabled = newValue }
    }

    var capturePaused: Bool {
        get { AppSettings.shared.effectiveCapturePaused() }
    }

    var pauseTimerMinutes: Int {
        get { AppSettings.shared.pauseTimerMinutes }
        set { AppSettings.shared.pauseTimerMinutes = newValue }
    }

    var ignoredBundleIdsText: String {
        get { AppSettings.shared.ignoredBundleIds.joined(separator: ", ") }
        set {
            let parts = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            AppSettings.shared.ignoredBundleIds = parts.map { String($0) }
        }
    }

    var itemCountText = ""
    var bytesText = ""

    weak var queueViewModel: QueueViewModel?

    init() {}

    func attach(queue: QueueViewModel) {
        queueViewModel = queue
    }

    func showWorkspace() {
        isVisible = true
        refreshAll()
        if !AppSettings.shared.captureOnboardingShown {
            showFirstRunCaptureInfo = true
        }
    }

    func acknowledgeCaptureOnboarding() {
        AppSettings.shared.captureOnboardingShown = true
        showFirstRunCaptureInfo = false
    }

    /// Installs ⌘⇧V, manual dump, and capture-pause callbacks (idempotent).
    static func installGlobalHotkeyHandlers() {
        GlobalHotkeyService.shared.onClipboardHUD = {
            Task { @MainActor in
                ClipboardHUDCoordinator.shared.toggle()
            }
        }
        GlobalHotkeyService.shared.onClipboardWorkspace = {
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
                hotkeyTarget?.showWorkspace()
            }
        }
        GlobalHotkeyService.shared.onManualDump = {
            Task { @MainActor in
                guard let w = hotkeyTarget else { return }
                ClipboardCaptureCoordinator.shared.performManualDump(
                    workspaceToast: { w.showToast($0) },
                    pinsFull: { _ in }
                )
            }
        }
        GlobalHotkeyService.shared.onToggleCapturePause = {
            Task { @MainActor in
                ClipboardCaptureCoordinator.shared.toggleCapturePause { msg in
                    hotkeyTarget?.showToast(msg)
                }
            }
        }
    }

    func hideWorkspace() {
        isVisible = false
    }

    func refreshAll() {
        reloadDump()
        reloadInbox()
        reloadBuckets()
        reloadStaging()
        reloadFooterStats()
    }
    
    func reloadDump() {
        do {
            dumpRows = try InboxStore.shared.inboxRows(search: nil, filter: .all)
        } catch {
            showToast("Could not load dump")
        }
    }

    func reloadInbox() {
        do {
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            inboxRows = try InboxStore.shared.inboxRows(
                search: q.isEmpty ? nil : q,
                filter: inboxFilter
            )
            if let sid = selectedInboxId, !inboxRows.contains(where: { $0.id == sid }) {
                selectedInboxId = inboxRows.first?.id
            }
            selectedInboxId = selectedInboxId ?? inboxRows.first?.id
        } catch {
            showToast("Could not load Inbox")
        }
        reloadFooterStats()
    }

    func scheduleInboxReload() {
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            reloadInbox()
        }
    }
    
    func scheduleDumpReload() {
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            reloadDump()
        }
    }

    func reloadBuckets() {
        do {
            try InboxStore.shared.pruneExpiredBuckets()
            buckets = try InboxStore.shared.allBuckets()
            if let bid = selectedBucketId, !buckets.contains(where: { $0.id == bid }) {
                selectedBucketId = buckets.first?.id
            }
            selectedBucketId = selectedBucketId ?? buckets.first?.id
            reloadBucketMembers()
        } catch {
            showToast("Could not load buckets")
        }
    }

    func reloadBucketMembers() {
        guard let bid = selectedBucketId else {
            bucketInboxRows = []
            return
        }
        do {
            let ids = try InboxStore.shared.inboxIds(inBucket: bid)
            var rows: [InboxRow] = []
            for id in ids {
                if let r = try InboxStore.shared.inboxRow(id: id) {
                    rows.append(r)
                }
            }
            bucketInboxRows = rows
        } catch {
            bucketInboxRows = []
        }
    }

    func reloadStaging() {
        do {
            stagingRows = try InboxStore.shared.stagingRows()
            if let sid = selectedStagingId, !stagingRows.contains(where: { $0.id == sid }) {
                selectedStagingId = stagingRows.first?.id
            }
            selectedStagingId = selectedStagingId ?? stagingRows.first?.id
        } catch {
            showToast("Could not load staging")
        }
    }

    func reloadFooterStats() {
        do {
            let t = try InboxStore.shared.inboxTotals()
            itemCountText = "\(t.count) / \(AppSettings.maxInboxItems) items"
            let mb = Double(t.totalBytes) / (1024 * 1024)
            let cap = Double(AppSettings.maxInboxBytes) / (1024 * 1024)
            bytesText = String(format: "%.1f / %.0f MB", mb, cap)
        } catch {
            itemCountText = ""
            bytesText = ""
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            toastMessage = nil
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            try? InboxStore.shared.addTextItem(text)
                            self.scheduleInboxReload()
                        }
                    } else if let str = item as? String {
                        Task { @MainActor in
                            try? InboxStore.shared.addTextItem(str)
                            self.scheduleInboxReload()
                        }
                    }
                }
                continue
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier) { item, _ in
                    if let url = item as? URL {
                        if let image = NSImage(contentsOf: url) {
                            Task { @MainActor in
                                try? InboxStore.shared.addImageItem(image)
                                self.scheduleInboxReload()
                            }
                        }
                    } else if let data = item as? Data, let image = NSImage(data: data) {
                        Task { @MainActor in
                            try? InboxStore.shared.addImageItem(image)
                            self.scheduleInboxReload()
                        }
                    }
                }
                continue
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data,
                       let urlStr = String(data: data, encoding: .utf8),
                       let url = URL(string: urlStr) {
                        if let image = NSImage(contentsOf: url) {
                            Task { @MainActor in
                                try? InboxStore.shared.addImageItem(image)
                                self.scheduleInboxReload()
                            }
                        } else if let text = try? String(contentsOf: url) {
                            Task { @MainActor in
                                try? InboxStore.shared.addTextItem(text)
                                self.scheduleInboxReload()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Inbox actions

    func togglePin(id: String) throws {
        guard let row = try InboxStore.shared.inboxRow(id: id) else { return }
        try InboxStore.shared.setPinned(id: id, pinned: !row.pinned)
        reloadInbox()
    }

    func deleteInbox(id: String) throws {
        try InboxStore.shared.deleteInboxItem(id: id)
        multiSelectedInboxIds.remove(id)
        if selectedInboxId == id { selectedInboxId = nil }
        reloadInbox()
        reloadBucketMembers()
    }

    func batchDeleteInbox() {
        let ids = multiSelectedInboxIds.isEmpty ? (selectedInboxId.map { [$0] } ?? []) : Array(multiSelectedInboxIds)
        guard !ids.isEmpty else { return }
        for id in ids {
            try? InboxStore.shared.deleteInboxItem(id: id)
        }
        multiSelectedInboxIds.removeAll()
        selectedInboxId = nil
        reloadInbox()
        reloadBucketMembers()
    }

    func batchPin(_ pinned: Bool) {
        let ids = multiSelectedInboxIds.isEmpty ? (selectedInboxId.map { [$0] } ?? []) : Array(multiSelectedInboxIds)
        guard !ids.isEmpty else { return }
        for id in ids {
            try? InboxStore.shared.setPinned(id: id, pinned: pinned)
        }
        multiSelectedInboxIds.removeAll()
        reloadInbox()
    }

    func toggleMultiSelect(_ id: String) {
        if multiSelectedInboxIds.contains(id) {
            multiSelectedInboxIds.remove(id)
        } else {
            multiSelectedInboxIds.insert(id)
        }
    }

    func appendSelectedTextToQueue() {
        guard let id = selectedInboxId, let row = inboxRows.first(where: { $0.id == id }), row.kind == .text, let t = row.textContent else { return }
        queueViewModel?.appendLinesToQueue([t])
        showToast("Appended to queue")
    }

    func copySelectedToClipboard() throws {
        guard let id = selectedInboxId else { return }
        try InboxStore.shared.copyInboxItemToPasteboard(id: id)
    }

    func pasteSelectedNow() {
        guard AccessibilityService.isTrusted() else {
            showToast("Enable Accessibility to paste")
            return
        }
        try? copySelectedToClipboard()
        PasteService.paste()
    }

    func exportImage(for row: InboxRow) {
        guard row.kind == .image, let url = InboxStore.shared.imageFileURL(for: row) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "ClipboardImage-\(row.id.prefix(8)).png"
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                Task { @MainActor in self.showToast("Exported") }
            } catch {
                Task { @MainActor in self.showToast("Export failed") }
            }
        }
    }

    // MARK: - Buckets

    func createBucket(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try InboxStore.shared.createBucket(named: trimmed)
            reloadBuckets()
            showToast("Bucket created")
        } catch {
            showToast("Could not create bucket")
        }
    }

    func deleteSelectedBucket() {
        guard let id = selectedBucketId else { return }
        do {
            try InboxStore.shared.deleteBucket(id: id)
            selectedBucketId = nil
            reloadBuckets()
        } catch {
            showToast("Could not delete bucket")
        }
    }

    func toggleBucketPin() {
        guard let id = selectedBucketId, let b = buckets.first(where: { $0.id == id }) else { return }
        do {
            try InboxStore.shared.setBucketPinned(id: id, pinned: !b.pinned)
            reloadBuckets()
        } catch {
            showToast("Could not update bucket")
        }
    }

    func sendSelectedInboxToBucket() {
        guard let bid = selectedBucketId, let iid = selectedInboxId else { return }
        do {
            try InboxStore.shared.addInboxItem(iid, toBucket: bid)
            reloadBucketMembers()
            showToast("Added to bucket")
        } catch {
            showToast("Could not add to bucket")
        }
    }

    func batchSendToBucket() {
        guard let bid = selectedBucketId else { return }
        let ids = multiSelectedInboxIds.isEmpty ? (selectedInboxId.map { [$0] } ?? []) : Array(multiSelectedInboxIds)
        guard !ids.isEmpty else { return }
        for id in ids {
            try? InboxStore.shared.addInboxItem(id, toBucket: bid)
        }
        multiSelectedInboxIds.removeAll()
        reloadBucketMembers()
        showToast("Added to bucket")
    }

    // MARK: - Staging

    func sendSelectedTextToStaging() {
        guard let id = selectedInboxId, let row = inboxRows.first(where: { $0.id == id }), row.kind == .text, let t = row.textContent else {
            showToast("Select a text item")
            return
        }
        do {
            try InboxStore.shared.addStagingText(t)
            reloadStaging()
            showToast("Sent to staging")
        } catch {
            showToast("Could not stage")
        }
    }

    func moveStaging(from offsets: IndexSet, to offset: Int) {
        var rows = stagingRows
        rows.move(fromOffsets: offsets, toOffset: offset)
        do {
            try InboxStore.shared.saveStagingOrder(rows)
            reloadStaging()
        } catch {
            showToast("Reorder failed")
        }
    }

    func deleteStagingSelected() {
        guard let id = selectedStagingId else { return }
        do {
            try InboxStore.shared.deleteStaging(id: id)
            selectedStagingId = nil
            reloadStaging()
        } catch {
            showToast("Could not delete")
        }
    }

    func applyStagingTransforms() {
        do {
            try InboxStore.shared.applyTransformToStaging(
                trim: transformTrim,
                regexPattern: transformRegex,
                replacement: transformReplacement,
                prefix: transformPrefix,
                suffix: transformSuffix
            )
            reloadStaging()
            showToast("Transforms applied")
        } catch {
            showToast("Transform failed")
        }
    }

    func requestSendStagingToQueue() {
        let lines = stagingRows.map(\.text).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            showToast("Staging is empty")
            return
        }
        if let q = queueViewModel, !q.items.isEmpty {
            pendingStagingExport = lines
            showSendQueueConfirm = true
        } else {
            queueViewModel?.appendLinesToQueue(lines)
            showToast("Sent to queue")
        }
    }

    func confirmSendStagingToQueue() {
        queueViewModel?.appendLinesToQueue(pendingStagingExport)
        pendingStagingExport = []
        showSendQueueConfirm = false
        showToast("Sent to queue")
    }

    func cancelSendStagingToQueue() {
        pendingStagingExport = []
        showSendQueueConfirm = false
    }
}
