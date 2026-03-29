import SwiftUI

/// Demo/Preview showing the HUD design concept
/// This is not used in production but helps visualize the design
struct ClipboardHUDDesignDemo: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("Universal Clipboard HUD Design")
                .font(.largeTitle.bold())
            
            Text("Press ⌘⇧V from anywhere to access recent clipboard items")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            // Mock HUD
            mockHUD
            
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "hand.tap", title: "Single Click", description: "Copy & paste immediately")
                featureRow(icon: "hand.tap.fill", title: "Double Click", description: "Copy only (no paste)")
                featureRow(icon: "arrow.left.arrow.right", title: "Arrow Keys", description: "Navigate between items")
                featureRow(icon: "hand.draw", title: "Drag Item", description: "Drag to any application")
                featureRow(icon: "escape", title: "Escape", description: "Dismiss HUD")
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            Text("The HUD floats above all apps and doesn't steal focus")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: 1000)
    }
    
    private var mockHUD: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Text("Recent Clipboard")
                    .font(.system(size: 12, weight: .semibold))
                
                Spacer()
                
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
            
            Divider()
            
            // Carousel
            HStack(spacing: 12) {
                mockCard(icon: "doc.text", text: "Hello, world!", time: "now", selected: false)
                mockCard(icon: "photo", text: nil, time: "2m", selected: true)
                mockCard(icon: "doc.text", text: "Long text that wraps...", time: "5m", selected: false)
                mockCard(icon: "doc.text", text: "https://apple.com", time: "1h", selected: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Footer
            HStack(spacing: 16) {
                footerHint(icon: "arrow.left.arrow.right", text: "Navigate")
                footerHint(icon: "return", text: "Paste")
                footerHint(icon: "escape", text: "Close")
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .frame(width: 700)
    }
    
    private func mockCard(icon: String, text: String?, time: String, selected: Bool) -> some View {
        VStack(spacing: 6) {
            if let text {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(selected ? .blue : .secondary)
                    
                    Text(text)
                        .font(.system(size: 11))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                }
            } else {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(selected ? .blue : .secondary)
                
                Rectangle()
                    .fill(.tertiary.opacity(0.3))
                    .frame(width: 100, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            Text(time)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(width: 140, height: 100)
        .background(selected ? Color.blue.opacity(0.15) : Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? Color.blue.opacity(0.5) : Color.white.opacity(0.2), lineWidth: selected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(selected ? 0.25 : 0.1), radius: selected ? 8 : 4, y: selected ? 4 : 2)
    }
    
    private func footerHint(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundStyle(.tertiary)
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview("HUD Design Demo") {
    ClipboardHUDDesignDemo()
        .frame(width: 1200, height: 900)
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}
