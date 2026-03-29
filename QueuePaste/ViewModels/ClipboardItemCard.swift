import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Individual card displaying a clipboard item in the HUD
struct ClipboardItemCard: View {
    let item: InboxRow
    let isSelected: Bool
    let isHovered: Bool
    
    @Environment(ClipboardHUDViewModel.self) private var viewModel
    
    private let cardWidth: CGFloat = 140
    private let cardHeight: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 6) {
            // Content preview
            contentPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Timestamp
            Text(relativeTime)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(isSelected ? 0.25 : 0.1), radius: isSelected ? 8 : 4, y: isSelected ? 4 : 2)
        .scaleEffect(isHovered ? 1.05 : (isSelected ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onDrag {
            createDragItem()
        }
    }
    
    // MARK: - Drag & Drop
    
    private func createDragItem() -> NSItemProvider {
        switch item.kind {
        case .text:
            if let text = item.textContent {
                let provider = NSItemProvider(object: text as NSString)
                return provider
            }
            return NSItemProvider()
            
        case .image:
            if let imageURL = InboxStore.shared.imageFileURL(for: item),
               let image = NSImage(contentsOf: imageURL) {
                let provider = NSItemProvider(object: image)
                return provider
            }
            return NSItemProvider()
        }
    }
    
    @ViewBuilder
    private var contentPreview: some View {
        switch item.kind {
        case .text:
            VStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                
                if let text = item.textContent {
                    Text(text)
                        .font(.system(size: 11))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                }
            }
            
        case .image:
            if let imageURL = InboxStore.shared.thumbFileURL(for: item),
               let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    
                    Text("Image")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var cardBackground: some View {
        ZStack {
            // Base blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            
            // Tint overlay
            if isSelected {
                Color.blue.opacity(0.15)
            } else if isHovered {
                Color.white.opacity(0.1)
            }
        }
    }
    
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.2),
                lineWidth: isSelected ? 2 : 1
            )
    }
    
    private var relativeTime: String {
        let interval = Date().timeIntervalSince(item.createdAt)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}

/// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview("Text Card") {
    let item = InboxRow(
        id: "1",
        createdAt: Date().addingTimeInterval(-300),
        kind: .text,
        textContent: "Hello, this is a sample clipboard text that might be a bit longer",
        imageRelPath: nil,
        thumbRelPath: nil,
        byteSize: 100,
        pinned: false,
        contentHash: "abc"
    )
    
    return ClipboardItemCard(item: item, isSelected: true, isHovered: false)
        .environment(ClipboardHUDViewModel())
        .frame(width: 200, height: 150)
        .background(Color.black.opacity(0.3))
}

#Preview("Image Card") {
    let item = InboxRow(
        id: "2",
        createdAt: Date().addingTimeInterval(-7200),
        kind: .image,
        textContent: nil,
        imageRelPath: "test.png",
        thumbRelPath: "test_thumb.jpg",
        byteSize: 50000,
        pinned: true,
        contentHash: "def"
    )
    
    return ClipboardItemCard(item: item, isSelected: false, isHovered: true)
        .environment(ClipboardHUDViewModel())
        .frame(width: 200, height: 150)
        .background(Color.black.opacity(0.3))
}
