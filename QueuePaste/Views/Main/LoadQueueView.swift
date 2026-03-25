import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LoadQueueView: View {
    @Environment(QueueViewModel.self) var vm
    @State private var showFileImporter = false

    var body: some View {
        @Bindable var vm = vm
        VStack(alignment: .leading, spacing: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    loadIntroBlock
                    Spacer(minLength: 8)
                    tryExampleButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    loadIntroBlock
                    tryExampleButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            if !vm.errorMessage.isEmpty {
                Label(vm.errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !vm.items.isEmpty, vm.state == .ready {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.secondary)
                    (Text("Queue is loaded — use ") + Text("Start Queue").fontWeight(.semibold) + Text(" in the sidebar or toolbar when you’re ready."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.08))
                }
                .transition(.opacity)
            }

            editorCard
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 220, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("queuePasteImportCSVRequested"))) { _ in
            showFileImporter = true
        }
        .padding(.top, 8)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
        .animation(.easeInOut(duration: 0.2), value: vm.items.count)
        .animation(.easeInOut(duration: 0.2), value: vm.state)
    }

    // MARK: - Intro & actions

    private var loadIntroBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Build your list")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("One line per item. Drag text or a file onto the field.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var tryExampleButton: some View {
        Button("Try example") {
            vm.loadExample()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private var loadIntoQueueButton: some View {
        Button {
            vm.loadItems(from: vm.inputText)
        } label: {
            Label("Load queue", systemImage: "arrow.down.doc")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var importCSVButton: some View {
        Button {
            showFileImporter = true
        } label: {
            Label("Import CSV…", systemImage: "doc.badge.arrow.up")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var bottomActionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                loadIntoQueueButton
                importCSVButton
                Spacer(minLength: 0)
                if !vm.items.isEmpty { clearQueueButton }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    loadIntoQueueButton
                    importCSVButton
                }
                if !vm.items.isEmpty {
                    clearQueueButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.3)
        }
    }

    private var clearQueueButton: some View {
        Button(role: .destructive) {
            vm.clearQueue()
        } label: {
            Label("Clear queue", systemImage: "trash")
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Editor

    private var editorCard: some View {
        @Bindable var vm = vm
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    vm.isDropTargeted ? Color.accentColor : Color.primary.opacity(0.08),
                    lineWidth: vm.isDropTargeted ? 2 : 1
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if vm.isDropTargeted {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if vm.inputText.isEmpty {
                Text("Paste or type here — one item per line")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $vm.inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(.clear)
                .padding(10)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 220, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity, alignment: .topLeading)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .onDrop(of: [.plainText, .fileURL], isTargeted: $vm.isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    // MARK: - Helpers

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in
                            vm.inputText = text
                            vm.loadItems(from: text)
                        }
                    }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    if let data = item as? Data,
                       let urlStr = String(data: data, encoding: .utf8),
                       let url = URL(string: urlStr) {
                        loadFile(url: url)
                    }
                }
                return
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadFile(url: url)
        case .failure(let error):
            Task { @MainActor in
                vm.errorMessage = "Could not open file: \(error.localizedDescription)"
            }
        }
    }

    private func loadFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            Task { @MainActor in
                vm.errorMessage = "Permission denied for that file."
            }
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            Task { @MainActor in
                if url.pathExtension.lowercased() == "csv" {
                    vm.loadCSVItems(text)
                } else {
                    vm.inputText = text
                    vm.loadItems(from: text)
                }
            }
        } catch {
            Task { @MainActor in
                vm.errorMessage = "Could not read file: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    LoadQueueView()
        .environment(QueueViewModel())
        .frame(width: 560, height: 520)
}
