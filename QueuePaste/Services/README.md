# QueuePaste Architecture: Services

The Services layer encapsulates all interactions with macOS low-level APIs, specifically `AppKit`, `CoreGraphics`, and the `Accessibility` framework. By isolating these APIs into distinct stateless services, we ensure the ViewModel remains testable and untangled from bridging logic.

## Components

1. **`AccessibilityService`**
   - AppKit / CoreGraphics integration requires explicit Accessibility permissions from the user.
   - This service wraps the `AXIsProcessTrustedWithOptions` C-API into a safe, Swifty interface.
   - Used by the ViewModel to determine if hotkeys can be registered and to trigger system permission prompts.

2. **`GlobalHotkeyService`**
   - A robust implementation of `CGEvent.tapCreate`.
   - Traps system-wide keyboard events before they reach focused applications.
   - **Mechanism:** Listens for specific keycodes and modifier flags (e.g., `Option`, `Command`). If a match occurs, it executes a callback to the ViewModel and drops the event (`return nil`) so the OS doesn't process it.
   - Runs its own `CFRunLoopSource` on the main loop.

3. **`PasteService`**
   - Orchestrates the actual `NSPasteboard` and simulated keystroke execution.
   - **Keystroke Simulation:** Generates synthetic `CGEvent` key down and key up events for `Command + V` (Keycode 9), routing them to the globally active application using `CGEvent.post(.cghidEventTap, ... )`.

4. **`QueueSessionStore`**
   - Maps between the `PersistedQueueSession` model and `UserDefaults.standard`.
   - Encodes data via `JSONEncoder` for fast, lightweight atomic persistence of the user's workflow state.

## Architectural Notes

- **Statelessness:** Services in `QueuePaste` do not hold application data. They perform physical/system actions and return execution control back to the ViewModel.
- **Thread Safety:** While services execute system commands, their callbacks to the ViewModel are strictly routed back to the Main Thread via `DispatchQueue.main.async` to ensure SwiftUI compatibility.
