import SwiftUI
import AppKit

/// A continuous feed showing all clipboard captures in chronological order (newest first).
struct DumpView: View {
    @Environment(WorkspaceViewModel.self) private var workspace
    @State private var showSettings = false
    
    var body: some View {
        @Bindable var w = workspace
        
        VStack(spacing: 0) {
            // Header controls
            HStack(spacing: 12) {
                Text("\(workspace.dumpRows.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if AppSettings.shared.passiveCaptureEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppSettings.shared.effectiveCapturePaused() ? Color.orange : Color.red)
                            .frame(width: 6, height: 6)
                        Text(AppSettings.shared.effectiveCapturePaused() ? "Paused" : "Recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle(isOn: $w.dumpShowImages) {
                    Label("Images", systemImage: "photo")
                        .labelStyle(.iconOnly)
                }
                .help("Show image previews")
                .toggleStyle(.button)
                .controlSize(.small)
                
                Toggle(isOn: $w.dumpCompactMode) {
                    Label("Compact", systemImage: "rectangle.compress.vertical")
                        .labelStyle(.iconOnly)
                }
                .help("Compact view")
                .toggleStyle(.button)
                .controlSize(.small)
                
                Toggle(isOn: $w.dumpAutoScroll) {
                    Label("Auto-scroll", systemImage: "arrow.down.to.line")
                        .labelStyle(.iconOnly)
                }
                .help("Auto-scroll to new items")
                .toggleStyle(.button)
                .controlSize(.small)
                
                Button {
                    showSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .labelStyle(.iconOnly)
                }
                .help("Dump settings")
                .controlSize(.small)
                .popover(isPresented: $showSettings) {
                    dumpSettingsPopover
                }
                
                Button {
                    workspace.reloadDump()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .help("Refresh dump")
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            
            Divider()
            
            // The dump feed
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: workspace.dumpCompactMode ? 4 : 8) {
                        ForEach(workspace.dumpRows) { row in
                            DumpItemRow(row: row, compact: workspace.dumpCompactMode, showImages: workspace.dumpShowImages)
                                .id(row.id)
                        }
                        
                        if workspace.dumpRows.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: workspace.dumpRows.count) { oldCount, newCount in
                    if workspace.dumpAutoScroll, newCount > oldCount, let first = workspace.dumpRows.first {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .queuePasteInboxDidChange)) { _ in
            workspace.scheduleDumpReload()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No clipboard history yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text("Copy something to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var dumpSettingsPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dump Settings")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Capture Deduplication", isOn: Binding(
                    get: { AppSettings.shared.captureDeduplication },
                    set: { AppSettings.shared.captureDeduplication = $0 }
                ))
                .help("When enabled, identical consecutive clipboard items are skipped")
                
                Text("With deduplication off, every clipboard change is captured, even duplicates. This creates a true dump of all clipboard activity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                Button("Clear All Clipboard History") {
                    // Confirmation and clear
                    showClearConfirmation()
                }
                .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
    
    private func showClearConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Clear All History?"
        alert.informativeText = "This will permanently delete all clipboard history. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear All")
        
        if alert.runModal() == .alertSecondButtonReturn {
            // Clear all non-pinned items
            for row in workspace.dumpRows where !row.pinned {
                try? workspace.deleteInbox(id: row.id)
            }
            workspace.reloadDump()
            workspace.showToast("History cleared")
        }
    }
}

/// Individual row in the dump feed.
struct DumpItemRow: View {
    let row: InboxRow
    let compact: Bool
    let showImages: Bool
    
    @Environment(WorkspaceViewModel.self) private var workspace
    @State private var isHovered = false
    
    private var relativeTime: String {
        let interval = Date().timeIntervalSince(row.createdAt)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Time indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                if row.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 50, alignment: .trailing)
            
            // Content
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                switch row.kind {
                case .text:
                    if let text = row.textContent {
                        Text(text)
                            .font(compact ? .caption : .body)
                            .lineLimit(compact ? 2 : 5)
                            .textSelection(.enabled)
                    }
                    
                case .image:
                    if showImages, let imageURL = InboxStore.shared.imageFileURL(for: row) {
                        if let nsImage = NSImage(contentsOf: imageURL) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: compact ? 120 : 240, maxHeight: compact ? 80 : 160)
                                .cornerRadius(4)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "photo")
                            Text("Image • \(ByteCountFormatter.string(fromByteCount: row.byteSize, countStyle: .memory))")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Quick actions (show on hover)
            if isHovered || compact {
                HStack(spacing: 4) {
                    Button {
                        try? InboxStore.shared.copyInboxItemToPasteboard(id: row.id)
                        workspace.showToast("Copied")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")
                    
                    Button {
                        try? workspace.deleteInbox(id: row.id)
                        workspace.scheduleDumpReload()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Delete")
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, compact ? 4 : 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview("Dump View - With Items") {
    let workspace = WorkspaceViewModel()
    workspace.dumpRows = [
        InboxRow(
            id: "1",
            createdAt: Date().addingTimeInterval(-30),
            kind: .text,
            textContent: "Hello, world! This is a test clipboard entry.",
            imageRelPath: nil,
            thumbRelPath: nil,
            byteSize: 45,
            pinned: false,
            contentHash: "abc123"
        ),
        InboxRow(
            id: "2",
            createdAt: Date().addingTimeInterval(-120),
            kind: .text,
            textContent: "Another clipboard item from 2 minutes ago. This one is longer and has more text to demonstrate line wrapping in the dump view.",
            imageRelPath: nil,
            thumbRelPath: nil,
            byteSize: 142,
            pinned: true,
            contentHash: "def456"
        ),
        InboxRow(
            id: "3",
            createdAt: Date().addingTimeInterval(-7200),
            kind: .text,
            textContent: "https://www.apple.com",
            imageRelPath: nil,
            thumbRelPath: nil,
            byteSize: 21,
            pinned: false,
            contentHash: "ghi789"
        )
    ]
    
    return DumpView()
        .environment(workspace)
        .frame(width: 600, height: 400)
}

#Preview("Dump View - Empty") {
    let workspace = WorkspaceViewModel()
    return DumpView()
        .environment(workspace)
        .frame(width: 600, height: 400)
}
