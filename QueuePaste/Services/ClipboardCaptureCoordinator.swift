import AppKit
import Foundation

/// Passive pasteboard polling + manual dump side effects (toast, inbox reload).
@MainActor
final class ClipboardCaptureCoordinator {
    static let shared = ClipboardCaptureCoordinator()

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    private init() {}

    func startMonitoring() {
        timer?.invalidate()
        // More aggressive polling for dump mode - check every 200ms instead of 350ms
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in ClipboardCaptureCoordinator.shared.pollPassive() }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func syncPasteboardChangeCount() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func pollPassive() {
        AppSettings.shared.clearTimedPauseIfExpired()
        guard AppSettings.shared.passiveCaptureEnabled else { return }
        guard !AppSettings.shared.effectiveCapturePaused() else { return }

        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        _ = try? InboxStore.shared.captureFromPasteboard(isManual: false)
        NotificationCenter.default.post(name: .queuePasteInboxDidChange, object: nil)
    }

    func performManualDump(workspaceToast: (String) -> Void, pinsFull: (String) -> Void) {
        do {
            let r = try InboxStore.shared.captureFromPasteboard(isManual: true)
            switch r {
            case .captured:
                workspaceToast("Saved to Inbox")
            case .skippedDuplicate:
                workspaceToast("Already captured")
            case .skippedEmpty:
                workspaceToast("Clipboard empty")
            case .skippedPinsFull(let msg):
                pinsFull(msg)
                workspaceToast(msg)
            }
        } catch {
            workspaceToast("Capture failed")
        }
        syncPasteboardChangeCount()
        NotificationCenter.default.post(name: .queuePasteInboxDidChange, object: nil)
    }

    func toggleCapturePause(toast: (String) -> Void) {
        let settings = AppSettings.shared
        if settings.effectiveCapturePaused() {
            settings.capturePaused = false
            settings.capturePauseUntil = nil
            toast("Capture resumed")
        } else {
            settings.capturePaused = true
            let mins = settings.pauseTimerMinutes
            if mins > 0 {
                settings.capturePauseUntil = Date().addingTimeInterval(TimeInterval(mins * 60))
            }
            toast(mins > 0 ? "Capture paused for \(mins)m" : "Capture paused")
        }
    }
}
