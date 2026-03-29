# QueuePaste Architecture: Models

This directory contains the core data structures and domain logic primitives that define the `QueuePaste` application state. These models rely purely on Foundation and Swift Standard Library concepts, intentionally keeping them decoupled from the UI (SwiftUI) and ViewModels.

## Overview

The domain model is minimal and value-semantic where possible. This ensures that modifications to the application state are predictable and safe across concurrent operations.

### Data Structures

1. **`QueueItem` (Struct)**
   - Represents a single entity within the paste queue.
   - **Properties:**
     - `id`: A unique `UUID` to guarantee Identifiable compliance for SwiftUI `ForEach`.
     - `text`: The actual `String` payload destined for the `NSPasteboard`.
     - `status`: Tracks the item's individual progression (`.pending`, `.pasted`, `.skipped`).
   - Acts as the fundamental unit of work within the `QueueViewModel`.

2. **`QueueState` (Enum)**
   - A finite state machine representing the macro state of the application.
   - **Cases:**
     - `.idle`: No data loaded.
     - `.ready`: Data loaded, awaiting user initiation.
     - `.active`: Queue is running; global hotkeys are actively intercepted.
     - `.paused`: Queue is loaded but temporarily suspended; hotkeys are deactivated.
     - `.complete`: The queue sequence has finished.
   - Provides computed properties (`displayName`, `color`) which the ViewModel consumes to drive UI state.

3. **`PersistedQueueSession` (Struct)**
   - The Data Transfer Object (DTO) used for taking snapshots of the application state.
   - **Conformance:** `Codable`
   - **Purpose:** Used by the `QueueSessionStore` to serialize the current `items`, `pointer`, and `state` to `UserDefaults`. This enables the robust crash-recovery and continuity features of the app.

4. **Clipboard Workspace types (`InboxModels.swift`)**
   - **`InboxItemKind`:** Distinguishes text vs. image rows stored in the local inbox.
   - **`InboxRow`:** Identified inbox record with timestamps, optional text or image relative paths, size, pin state, and content hash for deduplication.
   - **`BucketRow`:** Named grouping for inbox organization with optional expiry.
   - **`StagingRow`:** Ordered lines prepared for transforms and export into the paste queue.

## Design Philosophy

- **Value Types:** Structs and Enums are used exclusively to prevent unintended side effects from reference sharing.
- **Codability:** Core states are `Codable` to ensure zero-friction persistence.
- **UI Agnostic:** Models know nothing about `@Observable`, `SwiftUI`, or `AppKit`. They are purely structural.
