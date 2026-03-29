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
   - **Shortcuts (current build):** queue paste `⌥Space` (when consuming), pause/resume `⌥⌘P`, HUD toggle `⌥⌘H`; Clipboard HUD `⌘⇧V`, Clipboard Workspace `⌘⇧B`, manual dump `⌃⌥D`, capture pause `⌃⌥C` (wired in `QueuePasteApp` / `WorkspaceViewModel`).

3. **`PasteService`**
   - Orchestrates the actual `NSPasteboard` and simulated keystroke execution.
   - **Keystroke Simulation:** Generates synthetic `CGEvent` key down and key up events for `Command + V` (Keycode 9), routing them to the globally active application using `CGEvent.post(.cghidEventTap, ... )`.

4. **`QueueSessionStore`**
   - Maps between the `PersistedQueueSession` model and `UserDefaults.standard`.
   - Encodes data via `JSONEncoder` for fast, lightweight atomic persistence of the user's workflow state.

5. **`InboxDatabase` / `InboxStore`**
   - SQLite-backed metadata for inbox rows, buckets, and staging; large image payloads live on disk under paths resolved by `AppPaths`.

6. **`AppPaths` / `AppSettings`**
   - Application Support locations and user defaults for capture toggles, retention, and related workspace behavior.

7. **`ClipboardCaptureCoordinator`**
   - Observes pasteboard change counts on a timer for passive capture, respects pause and settings, and coordinates with `InboxStore`.

8. **`QueuePasteNotifications`**
   - Centralizes notification names used across UI and services where appropriate.

## Architectural Notes

- **Statelessness:** Most services do not own long-lived app data; `InboxStore` is an intentional exception as the clipboard workspace persistence layer.
- **Thread Safety:** While services execute system commands, their callbacks to the ViewModel are strictly routed back to the Main Thread via `DispatchQueue.main.async` to ensure SwiftUI compatibility.
