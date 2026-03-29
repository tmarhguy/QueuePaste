import Cocoa

/// Global CGEvent tap for QueuePaste hotkeys. Not `@MainActor`; handlers hop to main as needed.
final class GlobalHotkeyService: @unchecked Sendable {
    static let shared = GlobalHotkeyService()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let optionSpaceGate = OptionSpaceGate()

    var onHotKeyTriggered: (() -> Void)?
    var onPauseResumeTriggered: (() -> Void)?
    var onToggleHUDTriggered: (() -> Void)?
    var onClipboardWorkspace: (() -> Void)?
    var onClipboardHUD: (() -> Void)?
    var onManualDump: (() -> Void)?
    var onToggleCapturePause: (() -> Void)?

    /// When false, ⌥Space passes through to the system (queue not actively consuming).
    func setQueueConsumesOptionSpace(_ consumes: Bool) {
        optionSpaceGate.set(consumes)
    }

    /// Installs the HID tap once (⌘⇧V, manual dump, capture pause, queue keys). Returns false if Accessibility is off or tap creation failed.
    @discardableResult
    func ensureStarted() -> Bool {
        guard AccessibilityService.isTrusted() else { return false }
        if eventTap != nil { return true }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, _ -> Unmanaged<CGEvent>? in
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            let isOptionDown = flags.contains(.maskAlternate)
            let isCommandDown = flags.contains(.maskCommand)
            let isControlDown = flags.contains(.maskControl)
            let isShiftDown = flags.contains(.maskShift)

            // ⌘⇧V — Clipboard HUD (universal floating widget)
            if isCommandDown && isShiftDown && !isOptionDown && !isControlDown && keyCode == 9 {
                Task { @MainActor in GlobalHotkeyService.shared.onClipboardHUD?() }
                return nil
            }
            
            // ⌘⇧B — Clipboard Workspace (full app view)
            if isCommandDown && isShiftDown && !isOptionDown && !isControlDown && keyCode == 11 {
                Task { @MainActor in GlobalHotkeyService.shared.onClipboardWorkspace?() }
                return nil
            }

            // ⌃⌥D — manual dump to Inbox
            if isControlDown && isOptionDown && !isCommandDown && !isShiftDown && keyCode == 2 {
                Task { @MainActor in GlobalHotkeyService.shared.onManualDump?() }
                return nil
            }

            // ⌃⌥C — toggle passive capture pause
            if isControlDown && isOptionDown && !isCommandDown && !isShiftDown && keyCode == 8 {
                Task { @MainActor in GlobalHotkeyService.shared.onToggleCapturePause?() }
                return nil
            }

            if isOptionDown && !isControlDown && !isShiftDown {
                if keyCode == 49 && !isCommandDown {
                    if GlobalHotkeyService.shared.optionSpaceGate.get() {
                        Task { @MainActor in GlobalHotkeyService.shared.onHotKeyTriggered?() }
                        return nil
                    }
                    return Unmanaged.passUnretained(event)
                }
                if keyCode == 35 && isCommandDown {
                    Task { @MainActor in GlobalHotkeyService.shared.onPauseResumeTriggered?() }
                    return nil
                }
                if keyCode == 4 && isCommandDown {
                    Task { @MainActor in GlobalHotkeyService.shared.onToggleHUDTriggered?() }
                    return nil
                }
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: nil
        ) else { return false }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return true
    }

    /// Removes the tap (rarely needed; prefer toggling `setQueueConsumesOptionSpace`).
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private final class OptionSpaceGate: @unchecked Sendable {
        private let lock = NSLock()
        private var consumes = false

        func get() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return consumes
        }

        func set(_ value: Bool) {
            lock.lock()
            defer { lock.unlock() }
            consumes = value
        }
    }
}
