import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let queuePasteWorkspaceDismissRequested = Notification.Name("queuePasteWorkspaceDismissRequested")
}

// MARK: - Root UI

struct WorkspaceRootView: View {
    @Environment(WorkspaceViewModel.self) private var workspaceModel
    @Environment(QueueViewModel.self) private var queue
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @FocusState private var searchFocused: Bool

    private let corner: CGFloat = 20

    var body: some View {
        @Bindable var workspace = workspaceModel
        VStack(spacing: 0) {
            Picker("", selection: $workspace.selectedTab) {
                ForEach(WorkspaceTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            Group {
                switch workspace.selectedTab {
                case .dump:
                    DumpView()
                case .inbox:
                    inboxTab(workspace: workspace)
                case .buckets:
                    bucketsTab(workspace: workspace)
                case .staging:
                    stagingTab(workspace: workspace)
                case .queue:
                    queueTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer(workspace: workspace)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let toast = workspace.toastMessage {
                Text(toast)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 20)
            }
        }
        .onAppear { searchFocused = true }
        .onKeyPress(.return) {
            try? workspace.copySelectedToClipboard()
            return .handled
        }
        .background {
            Button("Paste now") { workspace.pasteSelectedNow() }
                .keyboardShortcut(.return, modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        }
        .alert("Clipboard capture", isPresented: $workspace.showFirstRunCaptureInfo) {
            Button("OK") { workspace.acknowledgeCaptureOnboarding() }
        } message: {
            Text("Passive capture is off by default. Turn it on in the footer when you want automatic history. Your data stays on this Mac.")
        }
        .alert("Add to queue?", isPresented: $workspace.showSendQueueConfirm) {
            Button("Cancel", role: .cancel) { workspace.cancelSendStagingToQueue() }
            Button("Append") { workspace.confirmSendStagingToQueue() }
        } message: {
            Text("The queue already has items. Append staging lines to the end?")
        }
    }

    // MARK: Inbox

    @ViewBuilder
    private func inboxTab(workspace: WorkspaceViewModel) -> some View {
        @Bindable var w = workspace
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Search", text: $w.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .onChange(of: w.searchText) { _, _ in
                        w.scheduleInboxReload()
                    }

                Picker("", selection: $w.inboxFilter) {
                    Text("All").tag(InboxListFilter.all)
                    Text("Text").tag(InboxListFilter.text)
                    Text("Images").tag(InboxListFilter.images)
                    Text("Pinned").tag(InboxListFilter.pinned)
                }
                .labelsHidden()
                .frame(width: 100)

                Toggle("Batch", isOn: $w.inboxBatchMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Select multiple rows for batch actions")
            }
            .padding(.horizontal, 16)

            if w.inboxBatchMode {
                HStack {
                    Button("Pin") { w.batchPin(true) }
                    Button("Unpin") { w.batchPin(false) }
                    Button("Delete", role: .destructive) { w.batchDeleteInbox() }
                    Button("To bucket") { w.batchSendToBucket() }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            List(selection: $w.selectedInboxId) {
                ForEach(w.inboxRows, id: \.id) { row in
                    inboxRowView(workspace: w, row: row)
                        .tag(Optional(row.id))
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu {
                inboxContextMenu(workspace: w)
            }
            .onDrop(of: [.plainText, .fileURL, .image], isTargeted: nil) { providers in
                w.handleDrop(providers: providers)
                return true
            }
        }
    }

    @ViewBuilder
    private func inboxRowView(workspace: WorkspaceViewModel, row: InboxRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if workspace.inboxBatchMode {
                Toggle("", isOn: Binding(
                    get: { workspace.multiSelectedInboxIds.contains(row.id) },
                    set: { on in
                        if on { workspace.multiSelectedInboxIds.insert(row.id) }
                        else { workspace.multiSelectedInboxIds.remove(row.id) }
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            }

            if row.kind == .image, let url = InboxStore.shared.thumbFileURL(for: row) {
                ThumbnailImageView(url: url)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 4) {
                if row.kind == .text {
                    Text(row.textContent ?? "")
                        .lineLimit(3)
                        .font(.body)
                } else {
                    Text("Image")
                        .font(.headline)
                }
                HStack {
                    Text(row.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if row.pinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onDrag {
            if row.kind == .text, let text = row.textContent {
                return NSItemProvider(object: text as NSString)
            } else if row.kind == .image, let url = InboxStore.shared.imageFileURL(for: row) {
                return NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)
            }
            return NSItemProvider()
        }
    }

    @ViewBuilder
    private func inboxContextMenu(workspace: WorkspaceViewModel) -> some View {
        Button("Copy") {
            try? workspace.copySelectedToClipboard()
        }
        Button("Paste now (⌘↩)") {
            workspace.pasteSelectedNow()
        }
        Divider()
        Button("Pin / Unpin") {
            if let id = workspace.selectedInboxId {
                try? workspace.togglePin(id: id)
            }
        }
        Button("Append to queue") {
            workspace.appendSelectedTextToQueue()
        }
        Button("Send to staging") {
            workspace.sendSelectedTextToStaging()
        }
        Divider()
        Button("Export image…") {
            if let id = workspace.selectedInboxId, let row = workspace.inboxRows.first(where: { $0.id == id }) {
                workspace.exportImage(for: row)
            }
        }
        Divider()
        Button("Send to bucket") {
            workspace.sendSelectedInboxToBucket()
        }
        Divider()
        Button("Delete", role: .destructive) {
            if let id = workspace.selectedInboxId {
                try? workspace.deleteInbox(id: id)
            }
        }
    }

    // MARK: Buckets

    @ViewBuilder
    private func bucketsTab(workspace: WorkspaceViewModel) -> some View {
        @Bindable var w = workspace
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if w.buckets.isEmpty {
                    Text("No buckets yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Bucket", selection: $w.selectedBucketId) {
                        ForEach(w.buckets, id: \.id) { b in
                            Text(b.name + (b.pinned ? " (pinned)" : "")).tag(Optional(b.id))
                        }
                    }
                    .frame(maxWidth: 280)
                }

                Button("New…") {
                    showNewBucketPrompt(workspace: w)
                }

                Button("Delete") { w.deleteSelectedBucket() }
                    .disabled(w.selectedBucketId == nil)

                Button("Pin") { w.toggleBucketPin() }
                    .disabled(w.selectedBucketId == nil)
            }
            .padding(.horizontal, 16)

            Text("Members")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            List(w.bucketInboxRows, id: \.id) { row in
                inboxRowView(workspace: w, row: row)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .onChange(of: w.selectedBucketId) { _, _ in
                w.reloadBucketMembers()
            }
        }
        .onAppear { w.reloadBuckets() }
    }

    private func showNewBucketPrompt(workspace: WorkspaceViewModel) {
        let alert = NSAlert()
        alert.messageText = "New bucket"
        alert.informativeText = "Ephemeral buckets expire after 24 hours unless pinned."
        let field = NSTextField(string: "")
        field.placeholderString = "Name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        alert.layout()
        let r = alert.runModal()
        if r == .alertFirstButtonReturn {
            workspace.createBucket(name: field.stringValue)
        }
    }

    // MARK: Staging

    @ViewBuilder
    private func stagingTab(workspace: WorkspaceViewModel) -> some View {
        @Bindable var w = workspace
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Delete line") { w.deleteStagingSelected() }
                Button("Send to queue") { w.requestSendStagingToQueue() }
                Spacer()
            }
            .padding(.horizontal, 16)

            GroupBox("Text transforms") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Trim whitespace", isOn: $w.transformTrim)
                    HStack {
                        Text("Regex")
                        TextField("Pattern", text: $w.transformRegex)
                            .textFieldStyle(.roundedBorder)
                        TextField("Replacement", text: $w.transformReplacement)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Prefix")
                        TextField("", text: $w.transformPrefix)
                            .textFieldStyle(.roundedBorder)
                        Text("Suffix")
                        TextField("", text: $w.transformSuffix)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button("Apply to all staging lines") {
                        w.applyStagingTransforms()
                    }
                }
                .padding(8)
            }
            .padding(.horizontal, 16)

            List(selection: $w.selectedStagingId) {
                ForEach(w.stagingRows, id: \.id) { row in
                    Text(row.text)
                        .lineLimit(4)
                        .tag(Optional(row.id))
                }
                .onMove { from, to in
                    w.moveStaging(from: from, to: to)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: Queue (read-only)

    private var queueTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Execution queue (paste with \(queue.pasteHotkeyLabel))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            List(Array(queue.items.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                    Text(item.text)
                        .lineLimit(2)
                    if index == queue.pointer, queue.state == .active || queue.state == .paused {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(workspace: WorkspaceViewModel) -> some View {
        @Bindable var w = workspace
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.itemCountText)
                    Text(w.bytesText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Toggle("Passive capture", isOn: $w.passiveCaptureEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                if w.capturePaused || AppSettings.shared.capturePaused {
                    Text("paused")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            HStack(alignment: .top) {
                Text("Ignore apps (bundle id, comma-separated)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("e.g. com.apple.Passwords", text: $w.ignoredBundleIdsText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }
            .padding(.horizontal, 16)

            HStack {
                Text("Pause timer (minutes, 0 = manual only)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Stepper(value: $w.pauseTimerMinutes, in: 0...120) {
                    Text("\(w.pauseTimerMinutes)m")
                        .font(.caption)
                        .frame(width: 36, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Thumbnail

private struct ThumbnailImageView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: url) {
            image = NSImage(contentsOf: url)
        }
    }
}
