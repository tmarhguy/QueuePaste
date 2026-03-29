import SwiftUI
import Observation

@Observable
@MainActor
class QueueViewModel {

    private let store: QueueSessionStore

    /// Snapshot waiting to be applied when the user taps Resume on the launch sheet.
    var pendingRestore: PersistedQueueSession?

    // MARK: - Queue State
    var items: [QueueItem] = []
    var pointer: Int = 0
    var state: QueueState = .idle
    var skippedItems: [QueueItem] = []

    // MARK: - HUD State
    var isHUDVisible: Bool = false
    var hudExpanded: Bool = false

    // MARK: - UI Feedback
    var statusMessage: String = ""
    var errorMessage: String = ""
    var showResumePrompt: Bool = false
    var showPermissionsSheet: Bool = false
    var showHotkeyConflict: Bool = false
    var inputText: String = ""
    var isDropTargeted: Bool = false
    var showCompletionBanner: Bool = false

    // MARK: - Computed
    var currentItem: QueueItem? {
        guard items.indices.contains(pointer) else { return nil }
        return items[pointer]
    }

    var nextItem: QueueItem? {
        let next = pointer + 1
        guard items.indices.contains(next) else { return nil }
        return items[next]
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(pointer) / Double(items.count)
    }

    var canStart: Bool { state == .ready }
    var canPause: Bool { state == .active }
    var canResume: Bool { state == .paused }
    var canStop: Bool { state == .active || state == .paused }
    var canSkip: Bool { state == .active && currentItem != nil }
    var canPrev: Bool { (state == .active || state == .paused) && pointer > 0 }
    var canReset: Bool { state != .idle }

    var pendingResumeItemCount: Int { pendingRestore?.items.count ?? 0 }

    /// 1-based position for the resume prompt (capped when the queue was completed).
    var pendingResumeCurrentItemNumber: Int {
        guard let p = pendingRestore, !p.items.isEmpty else { return 1 }
        let n = p.items.count
        return min(p.pointer + 1, n)
    }

    var pendingResumeSavedAt: Date? { pendingRestore?.savedAt }

    init(store: QueueSessionStore = QueueSessionStore()) {
        self.store = store
    }

    // MARK: - Loading

    func loadItems(from text: String) {
        let parsed = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { QueueItem(text: $0) }

        guard !parsed.isEmpty else {
            errorMessage = "No items found. Make sure each line has content."
            return
        }

        items = parsed
        pointer = 0
        skippedItems = []
        state = .ready
        errorMessage = ""
        statusMessage = "Loaded \(parsed.count) item\(parsed.count == 1 ? "" : "s")"
        showCompletionBanner = false
        persistSessionIfNeeded()
    }

    func loadExample() {
        let example = """
        alice@example.com
        bob@example.com
        carol@example.com
        dave@example.com
        eve@example.com
        """
        inputText = example
        loadItems(from: example)
    }

    func loadCSVItems(_ csvText: String) {
        let headerKeywords = ["name", "id", "title", "value", "item", "#", "email"]
        var lines = csvText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let first = lines.first {
            let firstCol = first.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces)
                .lowercased() ?? ""
            if headerKeywords.contains(firstCol) {
                lines.removeFirst()
            }
        }

        let parsed = lines
            .compactMap { line -> QueueItem? in
                let col = line.components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                return col.isEmpty ? nil : QueueItem(text: col)
            }

        guard !parsed.isEmpty else {
            errorMessage = "CSV imported 0 items. Check that the file has content in the first column."
            return
        }

        items = parsed
        pointer = 0
        skippedItems = []
        state = .ready
        errorMessage = ""
        statusMessage = "Loaded \(parsed.count) item\(parsed.count == 1 ? "" : "s") from CSV"
        showCompletionBanner = false
        persistSessionIfNeeded()
    }

    // MARK: - Queue Control

    private func setupHotkeyCallbacks() {
        GlobalHotkeyService.shared.onHotKeyTriggered = { [weak self] in
            self?.performPasteAdvance()
        }
        GlobalHotkeyService.shared.onPauseResumeTriggered = { [weak self] in
            guard let self = self else { return }
            if self.state == .paused { self.resume() }
            else if self.state == .active { self.pause() }
        }
        GlobalHotkeyService.shared.onToggleHUDTriggered = { [weak self] in
            self?.toggleHUD()
        }
    }

    func start() {
        guard state == .ready else { return }
        
        if !AccessibilityService.isTrusted() {
            AccessibilityService.promptForTrust()
            showPermissionsSheet = true
            return
        }
        
        state = .active
        isHUDVisible = true
        statusMessage = "Queue started"
        persistSessionIfNeeded()
        
        prepareClipboardForCurrentItem()
        GlobalHotkeyService.shared.setQueueConsumesOptionSpace(true)
        let success = GlobalHotkeyService.shared.ensureStarted()
        if !success && AccessibilityService.isTrusted() {
            showHotkeyConflict = true
        }
        setupHotkeyCallbacks()
    }

    func pause() {
        guard state == .active else { return }
        state = .paused
        statusMessage = "Paused at item \(pointer + 1)"
        persistSessionIfNeeded()
        
        GlobalHotkeyService.shared.setQueueConsumesOptionSpace(false)
    }

    func resume() {
        guard state == .paused else { return }
        
        if !AccessibilityService.isTrusted() {
            AccessibilityService.promptForTrust()
            showPermissionsSheet = true
            return
        }
        
        state = .active
        statusMessage = ""
        persistSessionIfNeeded()
        
        prepareClipboardForCurrentItem()
        GlobalHotkeyService.shared.setQueueConsumesOptionSpace(true)
        _ = GlobalHotkeyService.shared.ensureStarted()
        setupHotkeyCallbacks()
    }

    func stop() {
        state = .ready
        isHUDVisible = false
        statusMessage = "Queue stopped"
        persistSessionIfNeeded()
        
        GlobalHotkeyService.shared.setQueueConsumesOptionSpace(false)
    }

    func resetToStart() {
        pointer = 0
        skippedItems = []
        showCompletionBanner = false
        if state == .complete || state == .active || state == .paused {
            state = .ready
        }
        statusMessage = "Reset to beginning"
        persistSessionIfNeeded()
        
        GlobalHotkeyService.shared.setQueueConsumesOptionSpace(false)
    }

    func clearQueue() {
        items = []
        pointer = 0
        skippedItems = []
        state = .idle
        statusMessage = ""
        errorMessage = ""
        isHUDVisible = false
        showCompletionBanner = false
        inputText = ""
        persistSessionIfNeeded()
        
        GlobalHotkeyService.shared.setQueueConsumesOptionSpace(false)
    }

    // MARK: - Navigation
    
    func prepareClipboardForCurrentItem() {
        guard let item = currentItem else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
    }

    func performPasteAdvance() {
        guard state == .active, items.indices.contains(pointer) else { return }
        
        guard AccessibilityService.isTrusted() else {
            showPermissionsSheet = true
            return
        }
        
        prepareClipboardForCurrentItem()
        PasteService.paste()
        
        pointer += 1
        if pointer >= items.count {
            // Delay completion slightly to ensure the target app has time
            // to process the Cmd+V keystroke before our UI state changes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.complete()
            }
        } else {
            persistSessionIfNeeded()
            // Wait 300ms before preloading the next item. 50ms was too fast, causing
            // the target app to read the *next* item if it woke up slowly to process Cmd+V.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self.state == .active {
                    self.prepareClipboardForCurrentItem()
                }
            }
        }
    }

    func pasteNext() {
        guard state == .active, items.indices.contains(pointer) else { return }
        performPasteAdvance()
    }

    func skip() {
        guard state == .active, items.indices.contains(pointer) else { return }
        var skipped = items[pointer]
        skipped.isSkipped = true
        items[pointer] = skipped
        skippedItems.append(skipped)
        pointer += 1
        if pointer >= items.count {
            complete()
        } else {
            persistSessionIfNeeded()
            prepareClipboardForCurrentItem()
        }
    }

    func prev() {
        guard pointer > 0 else { return }
        pointer -= 1
        persistSessionIfNeeded()
        if state == .active {
            prepareClipboardForCurrentItem()
        }
    }

    private func complete() {
        state = .complete
        isHUDVisible = false
        showCompletionBanner = true
        let skippedCount = skippedItems.count
        statusMessage = "Queue complete — \(items.count) item\(items.count == 1 ? "" : "s") processed" +
            (skippedCount > 0 ? ", \(skippedCount) skipped" : "")
        persistSessionIfNeeded()
        GlobalHotkeyService.shared.setQueueConsumesOptionSpace(false)
    }

    // MARK: - Queue from Workspace / Staging

    /// Appends text lines to the execution queue (from Clipboard Workspace or Staging).
    func appendLinesToQueue(_ lines: [String]) {
        let trimmed = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }
        let newItems = trimmed.map { QueueItem(text: $0) }

        switch state {
        case .idle:
            items.append(contentsOf: newItems)
            if !items.isEmpty { state = .ready }
        case .ready, .active, .paused:
            items.append(contentsOf: newItems)
        case .complete:
            items.append(contentsOf: newItems)
            state = .ready
            showCompletionBanner = false
        }

        errorMessage = ""
        statusMessage = "Added \(newItems.count) item\(newItems.count == 1 ? "" : "s") to queue"
        persistSessionIfNeeded()
    }

    // MARK: - HUD

    func toggleHUD() { isHUDVisible.toggle() }
    func toggleHUDExpanded() { hudExpanded.toggle() }

    // MARK: - Session

    func checkForSavedSession() {
        guard let session = store.load(), session.isResumable else {
            pendingRestore = nil
            return
        }
        pendingRestore = session
        showResumePrompt = true
    }

    func resumeSession() {
        guard let snap = pendingRestore else {
            showResumePrompt = false
            return
        }
        items = snap.items
        pointer = snap.pointer
        state = snap.state
        skippedItems = snap.skippedItems
        inputText = snap.inputText
        errorMessage = ""

        let n = items.count
        if n > 0, pointer == n, state != .complete {
            state = .complete
        }

        showCompletionBanner = (state == .complete)
        isHUDVisible = (state == .active || state == .paused)

        pendingRestore = nil
        showResumePrompt = false
        persistSessionIfNeeded()
        
        if state == .active {
            prepareClipboardForCurrentItem()
            GlobalHotkeyService.shared.setQueueConsumesOptionSpace(true)
            let success = GlobalHotkeyService.shared.ensureStarted()
            if !success && AccessibilityService.isTrusted() {
                showHotkeyConflict = true
            }
            setupHotkeyCallbacks()
        }
    }

    func startFresh() {
        pendingRestore = nil
        showResumePrompt = false
        store.delete()
        clearQueue()
    }

    func clearSavedSession() {
        pendingRestore = nil
        showResumePrompt = false
        store.delete()
        clearQueue()
    }

    private func makeSnapshot() -> PersistedQueueSession {
        PersistedQueueSession(
            savedAt: Date(),
            items: items,
            pointer: pointer,
            state: state,
            skippedItems: skippedItems,
            inputText: inputText
        )
    }

    private func persistSessionIfNeeded() {
        if items.isEmpty, state == .idle {
            store.delete()
            return
        }
        do {
            try store.save(makeSnapshot())
        } catch {
            errorMessage = "Failed to save session: \(error.localizedDescription)"
        }
    }

    // MARK: - Hotkey labels

    var pasteHotkeyLabel: String { "⌥Space" }
    var pauseHotkeyLabel: String { "⌥⌘P" }
    var hudHotkeyLabel: String  { "⌥⌘H" }
}
