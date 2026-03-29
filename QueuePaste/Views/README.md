# QueuePaste Architecture: Views

SwiftUI structure for windows, sidebars, and supporting panels. Views stay small and observe shared view models from the environment.

## Windows and layout

1. **Main window (`ContentView` and `Views/Main/`)**
   - `NavigationSplitView` with a sidebar (`SidebarTab`): **Workspace** (Clipboard Workspace), **Prepare** (load queue), **Queue**, **Privacy** (permissions).
   - **Prepare:** `LoadQueueView`, list and transport controls (`QueueListView`, `QueueTransportPanel`, etc.).
   - On appear: attaches `WorkspaceViewModel` to the queue, installs global hotkey handlers, starts `ClipboardCaptureCoordinator`, and ensures `GlobalHotkeyService` is running.

2. **Queue HUD (`Views/HUD/`, `HUDWindowBridge`)**
   - Compact overlay for queue progress while pasting; shares `QueueViewModel` with the main window.

3. **Clipboard Workspace (`Views/Workspace/`, `WorkspaceWindowBridge`)**
   - Panel or embedded flows for dump, inbox, buckets, staging, and queue-related workspace actions. Uses `WorkspaceViewModel` for state.

4. **Menu bar extra**
   - Defined in `QueuePasteApp`; shows queue summary and workspace-oriented actions with the same environment objects.

## Patterns

- **Environment:** `QueuePasteApp` injects `QueueViewModel` and `WorkspaceViewModel` for a single shared instance across main UI, menu bar, and bridges.
- **HIG:** Standard system colors, `SF Symbols`, and secondary labels for supporting text.
