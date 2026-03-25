import Cocoa

@MainActor
class GlobalHotkeyService {
    static let shared = GlobalHotkeyService()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    var onHotKeyTriggered: (() -> Void)?
    var onPauseResumeTriggered: (() -> Void)?
    var onToggleHUDTriggered: (() -> Void)?
    
    func start() -> Bool {
        guard AccessibilityService.isTrusted() else { return false }
        
        if eventTap != nil { return true }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                
                // Option + Space
                // Space keycode = 49 (kVK_Space)
                let isOptionDown = flags.contains(.maskAlternate)
                let isCommandDown = flags.contains(.maskCommand)
                let isControlDown = flags.contains(.maskControl)
                let isShiftDown = flags.contains(.maskShift)
                
                // Keycodes: Space = 49, P = 35, H = 4
                if isOptionDown && !isControlDown && !isShiftDown {
                    if keyCode == 49 && !isCommandDown {
                        // Option + Space
                        Task { @MainActor in GlobalHotkeyService.shared.onHotKeyTriggered?() }
                        return nil
                    } else if keyCode == 35 && isCommandDown {
                        // Option + Cmd + P
                        Task { @MainActor in GlobalHotkeyService.shared.onPauseResumeTriggered?() }
                        return nil
                    } else if keyCode == 4 && isCommandDown {
                        // Option + Cmd + H
                        Task { @MainActor in GlobalHotkeyService.shared.onToggleHUDTriggered?() }
                        return nil
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: nil
        )
        
        guard let tap = tap else { return false }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        return true
    }
    
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
}
