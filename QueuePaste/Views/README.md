# QueuePaste Architecture: Views

The Views directory contains the SwiftUI structural components of the application. The UI is heavily fragmented into small, specialized views that observe the environment.

## Hierarchy & Windows

macOS applications require careful handling of window presentation. QueuePaste runs on a multi-window architecture:

1. **Main Window (`ContentView.swift` & `Views/Main/`)**
   - The primary interface where users load data and configure the initial queue.
   - **Key Views:**
     - `LoadQueueView`: Handles raw text input and drag-and-drop parsing.
     - `QueueListView`: A scrollable visualization of the queue.
     - `QueueTransportPanel`: The playback controls (Start, Pause, Reset, Skip).
   - Constrained by minimum sizes to ensure no UI clipping occurs.

2. **HUD Window (`HUDWindowBridge.swift` & `Views/HUD/`)**
   - The Heads-Up Display is a specialized, floating, borderless `NSWindow` that implements `.isMovableByWindowBackground`.
   - **Features:** 
     - Sits above all other applications (`.floating` window level).
     - Does not steal key focus (`.ignoresMouseEvents` depending on the state).
   - Provides a non-intrusive `HUDCompactView` visualization for the current item and progress natively above whatever application the user is pasting into.

3. **Menu Bar Extra**
   - Defined in the app's entry point, creating an `NSStatusItem` in the global menu bar for quick queue checks without invoking the main or HUD windows.

## Design Patterns

- **Environment Injection:** The `QueueViewModel` is instantiated once in `QueuePasteApp` and injected globally using `.environment(vm)`. Both the Main Window and the HUD Window share the exact same instance, achieving perfect state synchronization at all times.
- **Componentization:** Complex views like the sidebar are broken into `SidebarHotkeyFooter` and `StatusBannerView` to reduce structural nesting and improve Swift UI compile times and readability.
- **Native Look & Feel:** The app relies heavily on `.foregroundStyle(.secondary)` and standard `SF Symbols` to adhere strictly to Apple's Human Interface Guidelines (HIG) for macOS desktop utilities.
