# QueuePaste v1 — System Audit
> Reviewed 21 Swift source files. No assumptions made; every finding maps directly to code observed.

---

## 🔴 Critical — Fix Before Shipping

### 1. `GlobalHotkeyService` is NOT thread-safe (data race + potential crash)
**File:** [GlobalHotkeyService.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Services/GlobalHotkeyService.swift#L20-L50)

The `CGEventTapCallBack` closure runs on **a private CGEvent dispatch thread**. Inside that callback you directly call `GlobalHotkeyService.shared.onHotKeyTriggered?()` (line 36), reading `shared` — a `static let` — that's fine. But the callbacks themselves (`onHotKeyTriggered`, `onPauseResumeTriggered`, `onToggleHUDTriggered`) are plain vars on a class with no synchronization. They are simultaneously written from `@MainActor` (in `setupHotkeyCallbacks`) and read from the event-tap thread. This is a diagnosed Swift data race in Swift 6 strict concurrency. The `DispatchQueue.main.async` wrapper dispatches the *call* correctly but the *read* of the closure pointer still happens off-main.

**Fix:** Annotate `GlobalHotkeyService` with `@MainActor`, or gate the tap-thread read through a `DispatchQueue` or `@unchecked Sendable` actor-isolated approach.

---

### 2. `pasteNext()` (in ViewModel) does NOT actually paste — silent divergence in core flow
**File:** [QueueViewModel.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/ViewModels/QueueViewModel.swift#L284-L293)

`performPasteAdvance()` (line 258) **calls `PasteService.paste()`** — the real Cmd+V injection. `pasteNext()` (line 284) **does not**. The "Paste Next" button in the sidebar and the toolbar button both call `pasteNext()`, so clicking them only advances the pointer without actually pasting. The user would have to manually Cmd+V themselves. This contradicts the button's label and the user's mental model.

```swift
// pasteNext() — missing the actual paste:
func pasteNext() {
    guard state == .active, items.indices.contains(pointer) else { return }
    pointer += 1          // advances pointer ✅
    // PasteService.paste() is MISSING here ❌
    ...
}
```

**Fix:** Have `pasteNext()` call `performPasteAdvance()` (or inline the paste + delay logic), or rename it `advancePointer()` to match its true behavior and update all labels accordingly.

---

### 3. `QueueSessionStore` directory is never created before `load()`, risking a silent failure path
**File:** [QueueSessionStore.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Services/QueueSessionStore.swift#L15-L29)

`load()` calls `fileManager.fileExists(atPath:)` without first ensuring the parent directory exists. On first launch the directory won't exist, so `fileExists` returns `false` and `nil` is returned — which is actually fine in practice. However `save()` does `createDirectory(at:withIntermediateDirectories:)` inside a `do/catch` that silently swallows errors (line 44). If `save()` ever fails (permissions, sandbox, full disk), the user will lose their session with no error surfaced. The silent catch-all `// Best-effort persistence` is insufficient for a tool whose main value proposition is session continuity.

**Fix:** Surface the error as `vm.errorMessage` (pass the store's errors up through a `Result` or `throws`-style API, or use a callback).

---

### 4. The `Import CSV…` command in the menu bar is a stub — it does nothing
**File:** [QueuePasteApp.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/QueuePasteApp.swift#L18-L23)

```swift
Button("Import CSV…") {
    // Stub: trigger file importer
}
```

The actual `fileImporter` sheet exists in `LoadQueueView` and works fine, but the menu bar shortcut `⌘O` silently does nothing. A user trying to use the keyboard shortcut will think the app is broken.

**Fix:** Wire the command to `vm.showFileImporter = true` or use a `NotificationCenter` trigger → `LoadQueueView` listens and shows its `fileImporter`. Alternatively remove the stub entry until wired.

---

### 5. `HUDWindowBridge` does NOT update when `skippedItems` changes
**File:** [HUDWindowBridge.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Views/HUD/HUDWindowBridge.swift#L132-L158)

The bridge observes: `vm.isHUDVisible`, `vm.pointer`, `vm.state`, `vm.hudExpanded`, `vm.items.count`. It does **not** observe `vm.skippedItems`. If the user skips an item while expanded HUD is open, the skipped-items list inside the HUD will be stale until one of the other triggers fires. In practice a skip also increments `vm.pointer`, so it often coincidentally refreshes — but not if the pointer is at the last item and `skip()` leads directly to `complete()` (pointer is not incremented again).

**Fix:** Add `.onChange(of: vm.skippedItems.count)` to the bridge's observer set.

---

## 🟠 High Priority — Polish Before Launch

### 6. `progress` computed property can display "1 / 5" as "Done" at item 5, but shows 80% progress
**File:** [QueueViewModel.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/ViewModels/QueueViewModel.swift#L45-L48)

```swift
var progress: Double {
    guard !items.isEmpty else { return 0 }
    return Double(pointer) / Double(items.count)   // When pointer==5, count==5 → 1.0 only AFTER completion
}
```

The HUD's `progressMetricsRow` shows `vm.pointer + 1` as the current item number (line 170). So when the user is about to paste item 5 of 5, the counter shows **"5 / 5"** but the progress bar is at **80%** (pointer=4, 4/5=0.8). The bar only hits 100% after `complete()` is called and pointer becomes 5. This creates a visible desync between the number and the bar on the last item.

**Fix:** `return Double(min(pointer + 1, items.count)) / Double(items.count)` for the active/paused state, or rethink the convention so the bar reflects "items completed" not "pointer position."

---

### 7. `HUDWindowController.update()` replaces `rootView` with a new `AnyView` on every state change
**File:** [HUDWindowBridge.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Views/HUD/HUDWindowBridge.swift#L65-L67)

```swift
func update<Content: View>(content: Content) {
    hostingView?.rootView = AnyView(content)  // type-erased on every change
}
```

`AnyView` wrapping defeats SwiftUI's structural diffing. Every `.onChange` trigger rebuilds the entire HUD content tree without SwiftUI's cheap diff. On fast repeated pastes (hotkey spam), this creates unnecessary re-renders and can cause animation jitter on the HUD. The HUD should instead be driven purely by `@Observable` state bindings — the container already has `@Environment(QueueViewModel.self)` so it will update automatically if the `NSHostingView`'s root view is set once and never replaced.

**Fix:** Set `rootView` only once on `show()`. Since `HUDContainerView` already reads `@Environment(QueueViewModel.self)` (an `@Observable` class), SwiftUI will automatically update it on every relevant state change without any manual `.onChange` triggers.

---

### 8. `loadCSVItems` only reads the first column and uses a naive comma split — breaks quoted CSV
**File:** [QueueViewModel.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/ViewModels/QueueViewModel.swift#L109-L145)

```swift
let col = line.components(separatedBy: ",").first?  // naive split — breaks for: "Smith, John",john@...
```

Any CSV where the first column contains a comma (e.g., names: `"Smith, John"`) will truncate to `"Smith`. RFC 4180 CSV requires handling quoted fields. This will silently import wrong data with no user-visible error.

**Fix:** Use a proper CSV parser. For v1, at minimum detect and strip quote wrapping: `col.trimmingCharacters(in: CharacterSet(charactersIn: "\""))`. Document the column-1-only limitation in the UI.

---

### 9. `QueueItem` text is never sanitized for clipboard injection risk
**File:** [QueueViewModel.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/ViewModels/QueueViewModel.swift#L76-L80), [PasteService.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Services/PasteService.swift)

Items are `trimmingCharacters(in: .whitespaces)` but no other sanitization occurs. If a user loads a CSV from an untrusted source containing very long strings (e.g., 100K chars), pasting via Cmd+V into a target application could hang or crash that app. At minimum, a character/byte cap should be enforced with a user-visible warning.

**Fix:** Add a max-item-length cap (e.g., 4096 chars) in `loadItems` and `loadCSVItems` with a UI warning if any items were truncated.

---

### 10. `AccessibilityService` is never polled for de-elevation — trust granted mid-session is never detected
**File:** [AccessibilityService.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Services/AccessibilityService.swift)

The app checks `isTrusted()` at `start()` and `resume()`. If the user revokes accessibility in System Settings while the queue is active, the next hotkey will fail silently (CGEvent tap sees no events) or crash. There's no recovery path; the user has no idea what happened.

**Fix:** Poll `isTrusted()` periodically (e.g., every 5s via a `Timer`) while state is `.active`, and if it returns `false`, auto-pause with a sheet or banner prompting the user to re-grant.

---

### 11. Completed items cannot be individually revisited or un-skipped
**File:** [QueueViewModel.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/ViewModels/QueueViewModel.swift#L295-L308)

`skip()` marks items as `isSkipped = true` in the items array, but there is no `unskip()` or "re-paste skipped" feature. The Queue List view shows them as struck through. The user has no way to paste a skipped item without doing a full reset. For v1 use cases (entering field-by-field data), this is a real gap.

---

### 12. `QueueState.color` returns a `String`, not a `Color` — unused and misleading
**File:** [QueueState.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Models/QueueState.swift#L20-L28)

```swift
var color: String {
    case .complete: return "purple"  // purple, but UI has since standardized on .blue for complete
    ...
}
```

This property is defined but **never called anywhere** in the codebase. The UI computes its own colors inline (`sessionStateColor`, `progressTint`, `statusColor` etc.), and they don't agree — `QueueState.color` says `"purple"` for complete, but `QueueTransportPanel.sessionStateColor` uses `.blue`, `StatusBannerView.statusColor` uses `.blue`, and `HUDCompactView.progressTint` uses `.purple`. These inconsistencies exist because the model's color property was abandoned.

**Fix:** Delete `QueueState.color`, then audit and standardize: decide on one color per state and use a single computed `Color` property in `QueueState`, expressed as `Color` not `String`.

---

## 🟡 Medium Priority — Improvements Worth Making

### 13. No undo support in the text editor
The `TextEditor` in `LoadQueueView` benefits from system undo (it's built in). But calling `vm.loadItems(from:)` replaces `vm.items`, `vm.pointer`, and `vm.state` — there's no undo for that action. If a user accidentally clicks "Load Queue" or "Try Example" over existing data, it's gone.

**Fix:** Implement `UndoManager` for the `loadItems` / `loadCSVItems` operations, or add a confirmation alert when overwriting an active or non-empty queue (state ≠ `.idle`).

---

### 14. `pasteHotkeyLabel`, `pauseHotkeyLabel`, `hudHotkeyLabel` are hardcoded strings in the ViewModel
**File:** [QueueViewModel.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/ViewModels/QueueViewModel.swift#L415-L417)

```swift
var pasteHotkeyLabel: String { "⌥Space" }
```

These labels are hardcoded but they are also hardcoded in `GlobalHotkeyService` (keycode + flag checks). They must be manually kept in sync. If someone ever changes a hotkey, they'll need to update at least 3 places.

**Fix:** Define the keycodes, flags, and display strings in a single `HotkeyConfig` struct and reference it from both `GlobalHotkeyService` and the label properties.

---

### 15. `ControlPanelView` is a dead file — preview-only, never used in the app
**File:** [ControlPanelView.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Views/Main/ControlPanelView.swift)

The file comments say `/// Preview-only`. It imports and composes two views but is never referenced in `ContentView` or any scene. It's inert code that will confuse future contributors.

**Fix:** Delete the file, or rename it clearly to `ControlPanelPreview.swift` and wrap the struct in `#if DEBUG`.

---

### 16. `ResumeSessionView` has no minimum height — can be a tiny empty sheet
**File:** [ResumeSessionView.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Views/Supporting/ResumeSessionView.swift#L69)

The sheet is `frame(width: 320)` with no height constraint. If the `ScrollView` collapses, the sheet can present as a nearly-invisible sliver. Add a `frame(minHeight: 300)`.

---

### 17. `PersistedQueueSession.schemaVersion` is 1 with no migration path
**File:** [QueueSessionStore.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Services/QueueSessionStore.swift#L22-L24)

```swift
if session.schemaVersion != PersistedQueueSession.currentSchemaVersion {
    return nil   // data silently discarded
}
```

When you add a new field in v1.1+, bumping schema from 1→2 will silently discard all existing user sessions with no migration. Given the app's value is queue continuity, silent data loss on update is damaging.

**Fix:** Implement a migration block: load as a raw dictionary, detect version, migrate fields incrementally, then decode. Even a TODOcomment with the pattern documented would be better than the current cliff.

---

### 18. The hotkey conflict message is too generic
**File:** [HotkeyConflictView.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Views/Supporting/HotkeyConflictView.swift#L15-L17)

```swift
Text("⌥Space is unavailable")
```

The message doesn't explain *why* (e.g., another app owns the event tap) or what the user can do about it. A user might think the app is broken.

**Fix:** Add a help text: "Another app may be intercepting this key. Try quitting other utilities (Raycast, Alfred, etc.) and restart the queue."

---

### 19. `QueueListView` header count overflows on completion — shows "position 6/5"
**File:** [QueueListView.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Views/Main/QueueListView.swift#L28)

```swift
Text("... position \(min(vm.pointer + 1, vm.items.count))")
```

This *does* use `min()`, catching the overflow. ✅ But the "position" label when the state is `.complete` (pointer == items.count) shows "position 5" for a 5-item queue, implying there's still a 5th item to paste when all are done. The label should change to something like "Complete" or "All done."

---

### 20. No keyboard navigation for the Queue List View rows
**File:** [QueueListView.swift](file:///Users/tmarhguy/QueuePaste/QueuePaste/QueuePaste/Views/Main/QueueListView.swift)

The list is purely display. There's no way to click a row to jump the pointer there, or use arrow keys + Return to navigate (which would be very useful for reordering focus mid-queue). The list is visually interactive in appearance but passive.

---

## 🟢 What Is Already Great

| Area | What's Well Done |
|---|---|
| **Architecture** | Clean MVVM. `@Observable` + `@MainActor` on the ViewModel is modern and correct. Services are injected and individually replaceable. |
| **Session persistence** | Atomic write (`options: .atomic`), pointer clamping on load, schema versioning foundation, and `isResumable` gating are all solid. |
| **HUD design** | `NSPanel` with `.nonactivatingPanel` is the right call. `isMovableByWindowBackground`, `canJoinAllSpaces`, and `fullScreenAuxiliary` are all correct. Vibrancy (`.ultraThinMaterial`) with `reduceTransparency` fallback is excellent. |
| **Accessibility flow** | Separation of `isTrusted()` (silent check) and `promptForTrust()` (system dialog) is correct. Gate on `start()` and `resume()` is the right UX moment. |
| **Hotkey implementation** | Using a `CGEventTap` at `.cghidEventTap` / `.headInsertEventTap` with event consumption (return `nil`) is the correct low-level approach for a paste utility. |
| **Responsive layout** | `ViewThatFits`, `navigationSplitViewColumnWidth`, hysteresis split-collapse logic, `safeAreaInset` for pinned footer — all thoughtful and correct. |
| **Previews** | Every view has a `#Preview` with meaningful state. Some have multiple variants (HUD active/expanded). This is production-quality developer ergonomics. |
| **Error messages** | Errors surface in `vm.errorMessage` and animate in/out. The `Dismiss` button works. CSV import has a clear, specific error message. |
| **File import** | `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource` are correctly bracketed with `defer`. Drop + file importer both covered. |
| **No telemetry** | The privacy statement in `PermissionsView` is accurate: no network calls, no analytics, pure local-file persistence. This is correct and trustworthy. |
| **MenuBarExtra** | Using `.menu` style with a system SF Symbol is the right macOS-native approach. ARIA label on the icon is set. |

---

## Summary Scorecard

| Category | Score | Notes |
|---|---|---|
| Core paste logic | 6/10 | `pasteNext()` doesn't paste (Critical #2) |
| Thread safety | 5/10 | Hotkey callbacks unprotected (Critical #1) |
| Persistence | 7/10 | Atomic writes ✅, silent failure ❌, no migration plan ❌ |
| UI polish | 8/10 | Beautiful. Minor state-color inconsistency, progress bar desync |
| Accessibility | 7/10 | No de-elevation polling, no VoiceOver labels on queue rows |
| CSV handling | 5/10 | Naive first-column comma split breaks quoted fields |
| Keyboard nav | 6/10 | Good hotkeys, but no list row navigation |
| Code hygiene | 8/10 | Clean, well-named. Dead `ControlPanelView` + unused `QueueState.color` |
| **Overall** | **7/10** | Strong foundation. Two critical bugs, ~6 high-priority gaps before v1 is bulletproof |
