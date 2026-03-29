# QueuePaste Architecture: ViewModels

This directory houses presentation logic that bridges core models to SwiftUI. The app follows MVVM with `@MainActor` and `@Observable` where appropriate for the main window and workspace.

## `QueueViewModel`

Primary source of truth for the **paste queue**: items, pointer, `QueueState`, HUD visibility, CSV import, and coordination with `GlobalHotkeyService`, `PasteService`, and `QueueSessionStore`. Hotkey-driven paste advances use timed main-queue delays so the target app can read the pasteboard before the next item is prepared.

## `WorkspaceViewModel`

Owns **Clipboard Workspace** UI state: tabs (Dump, Inbox, Buckets, Staging, Queue), search and filters, multi-select, staging transforms, toasts, and visibility. Registers with global hotkeys (`WorkspaceViewModel.registerForGlobalHotkeys`) and attaches to `QueueViewModel` for operations that move lines from staging into the queue. Settings such as passive capture are surfaced through `AppSettings`.

## Clipboard HUD stack

- **`ClipboardHUDViewModel` / `ClipboardHUDView` / `ClipboardItemCard`:** Model and SwiftUI for the universal floating Clipboard HUD (Command-Shift-V), coordinated by `ClipboardHUDCoordinator` from the app entry point.
- **`ClipboardHUDWindow`:** AppKit window hosting for the HUD layer.

## `DumpView`

SwiftUI surface for the live dump / preview of captured content within the workspace.

## Design notes

- **Single responsibility:** ViewModels decide *what* changes; services perform system I/O.
- **Main thread:** Queue and workspace mutations that affect SwiftUI run on the main actor.
