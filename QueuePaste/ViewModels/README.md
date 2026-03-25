# QueuePaste Architecture: ViewModels

This directory houses the presentation logic that bridge our core models to the SwiftUI interface. It adheres strictly to the Model-View-ViewModel (MVVM) design pattern.

## Core Component: `QueueViewModel`

`QueueViewModel` operates as the singular Source of Truth for the entire application. It runs on the `@MainActor` to guarantee thread-safe UI updates and utilizes the modern Swift `@Observable` macro to power the SwiftUI views reactively.

### Responsibilities

1. **State Management**
   - Maintains the complete list of `items` (`[QueueItem]`) and tracks the current `pointer` (index).
   - Manages the active `QueueState`.
   - Controls HUD visibility and Window expansion limits.

2. **Hotkeys & System Integration**
   - Interfaces heavily with `GlobalHotkeyService` to register key-down event taps (`⌥Space`, `⌥⌘P`, `⌥⌘H`).
   - Translates system hotkey events into state mutations (e.g., advancing the queue pointer, pausing).
   - Orchestrates clipboard preparation via `PasteService` milliseconds prior to simulating the keystroke.

3. **Persistence Orchestration**
   - Listens to internal state mutations and periodically writes snapshots using `QueueSessionStore`.
   - Responsible for restoring pending sessions upon application launch.

4. **Data Ingestion**
   - Processes raw text payloads and CSV imports, converting them into valid `[QueueItem]` collections while removing malformed or empty data.

## Concurrency and Timing

A critical aspect of `QueueViewModel` is its precise management of dispatch queues during paste operations:
- When advancing the pointer (`performPasteAdvance`), the ViewModel relies on `DispatchQueue.main.asyncAfter` delays to ensure that the target application has sufficient time to read `NSPasteboard` contents before the ViewModel overwrites it with the next item.
- **Why?** Rapid sequential `⌥Space` presses can occasionally outpace traditional macOS event loops in target applications (like web browsers).

## Design Philosophy 

- **Single Responsibility:** The ViewModel handles *what* happens, while delegating the *how* to the `Services` layer.
- **Reactive Safety:** All properties mutated here naturally trigger view redraws across both the Main Window and the HUD due to `@Observable` running on the Main Thread.
