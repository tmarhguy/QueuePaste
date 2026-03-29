import SwiftUI
import AppKit

/// Main HUD view displaying recent clipboard items
struct ClipboardHUDView: View {
    @Environment(ClipboardHUDViewModel.self) private var viewModel
    @State private var isDragging = false
    
    var body: some View {
        @Bindable var vm = viewModel
        
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content (layout-dependent)
            if viewModel.recentItems.isEmpty {
                emptyState
            } else {
                if viewModel.layout == .horizontal {
                    horizontalCarousel
                } else {
                    verticalGrid
                }
            }
            
            // Footer hints
            footer
        }
        .background(hudBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
        .onAppear {
            viewModel.loadRecentItems()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            Text("Recent Clipboard")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Layout toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.layout = viewModel.layout == .horizontal ? .vertical : .horizontal
                }
            } label: {
                Image(systemName: viewModel.layout.icon)
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Switch to \(viewModel.layout == .horizontal ? "grid" : "horizontal") layout")
            
            // Keyboard hint
            Text("⌘⇧V")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.tertiary.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Move window as user drags header
                    if let window = NSApp.windows.first(where: { $0 is ClipboardHUDWindow }) {
                        let currentOrigin = window.frame.origin
                        let newOrigin = NSPoint(
                            x: currentOrigin.x + value.translation.width,
                            y: currentOrigin.y - value.translation.height
                        )
                        window.setFrameOrigin(newOrigin)
                    }
                }
        )
    }
    
    // MARK: - Layouts
    
    private var horizontalCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.recentItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemCard(
                            item: item,
                            isSelected: index == viewModel.selectedIndex,
                            isHovered: index == viewModel.hoveredIndex
                        )
                        .id(item.id)
                        .onHover { hovering in
                            viewModel.hoveredIndex = hovering ? index : nil
                        }
                        .onTapGesture {
                            // Just select and paste - don't copy unnecessarily
                            viewModel.selectItem(at: index)
                            viewModel.pasteSelectedItem()
                        }
                        .contextMenu {
                            Button("Paste") {
                                viewModel.selectItem(at: index)
                                viewModel.pasteItem(item)
                            }
                            Button("Copy to Clipboard") {
                                viewModel.copyItem(item)
                            }
                            Divider()
                            if item.pinned {
                                Button("Unpin") {
                                    try? InboxStore.shared.setPinned(id: item.id, pinned: false)
                                    viewModel.loadRecentItems()
                                }
                            } else {
                                Button("Pin") {
                                    try? InboxStore.shared.setPinned(id: item.id, pinned: true)
                                    viewModel.loadRecentItems()
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.deleteItem(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 124)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                guard newIndex < viewModel.recentItems.count else { return }
                let item = viewModel.recentItems[newIndex]
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(item.id, anchor: .center)
                }
            }
        }
    }
    
    private var verticalGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 140, maximum: 140), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(viewModel.recentItems.enumerated()), id: \.element.id) { index, item in
                    ClipboardItemCard(
                        item: item,
                        isSelected: index == viewModel.selectedIndex,
                        isHovered: index == viewModel.hoveredIndex
                    )
                    .id(item.id)
                    .onHover { hovering in
                        viewModel.hoveredIndex = hovering ? index : nil
                    }
                    .onTapGesture {
                        // Just select and paste - don't copy unnecessarily
                        viewModel.selectItem(at: index)
                        viewModel.pasteSelectedItem()
                    }
                    .contextMenu {
                        Button("Paste") {
                            viewModel.selectItem(at: index)
                            viewModel.pasteItem(item)
                        }
                        Button("Copy to Clipboard") {
                            viewModel.copyItem(item)
                        }
                        Divider()
                        if item.pinned {
                            Button("Unpin") {
                                try? InboxStore.shared.setPinned(id: item.id, pinned: false)
                                viewModel.loadRecentItems()
                            }
                        } else {
                            Button("Pin") {
                                try? InboxStore.shared.setPinned(id: item.id, pinned: true)
                                viewModel.loadRecentItems()
                            }
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            viewModel.deleteItem(item)
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(height: viewModel.recentItems.count <= 4 ? 140 : 280)
    }
    
    // MARK: - States
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text("No clipboard history")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            Text("Copy something to get started")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 124)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9))
                Text("Navigate")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
            
            HStack(spacing: 4) {
                Image(systemName: "return")
                    .font(.system(size: 9))
                Text("Paste")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
            
            HStack(spacing: 4) {
                Image(systemName: "delete.left")
                    .font(.system(size: 9))
                Text("Delete")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
            
            HStack(spacing: 4) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 9))
                Text("Drag")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
            
            HStack(spacing: 4) {
                Image(systemName: "escape")
                    .font(.system(size: 9))
                Text("Close")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
            
            Spacer()
            
            if let item = viewModel.recentItems[safe: viewModel.selectedIndex], item.pinned {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                    Text("Pinned")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private var hudBackground: some View {
        ZStack {
            // Base blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            
            // Slight tint
            Color.black.opacity(0.05)
        }
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview("HUD with Items") {
    let vm = ClipboardHUDViewModel()
    vm.recentItems = [
        InboxRow(
            id: "1",
            createdAt: Date().addingTimeInterval(-30),
            kind: .text,
            textContent: "Hello, world!",
            imageRelPath: nil,
            thumbRelPath: nil,
            byteSize: 13,
            pinned: false,
            contentHash: "a"
        ),
        InboxRow(
            id: "2",
            createdAt: Date().addingTimeInterval(-120),
            kind: .text,
            textContent: "This is a longer clipboard entry that demonstrates text wrapping in the card view",
            imageRelPath: nil,
            thumbRelPath: nil,
            byteSize: 80,
            pinned: true,
            contentHash: "b"
        ),
        InboxRow(
            id: "3",
            createdAt: Date().addingTimeInterval(-3600),
            kind: .image,
            textContent: nil,
            imageRelPath: "test.png",
            thumbRelPath: "test_thumb.jpg",
            byteSize: 50000,
            pinned: false,
            contentHash: "c"
        ),
        InboxRow(
            id: "4",
            createdAt: Date().addingTimeInterval(-7200),
            kind: .text,
            textContent: "https://www.apple.com/mac",
            imageRelPath: nil,
            thumbRelPath: nil,
            byteSize: 25,
            pinned: false,
            contentHash: "d"
        )
    ]
    
    return ClipboardHUDView()
        .environment(vm)
        .frame(width: 700, height: 200)
        .background(Color.gray.opacity(0.2))
}

#Preview("HUD Empty") {
    let vm = ClipboardHUDViewModel()
    return ClipboardHUDView()
        .environment(vm)
        .frame(width: 700, height: 200)
        .background(Color.gray.opacity(0.2))
}
