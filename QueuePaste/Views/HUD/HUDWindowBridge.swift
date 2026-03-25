import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted from the HUD chrome to hide the panel and clear `QueueViewModel.isHUDVisible`.
    static let queuePasteHUDDismissRequested = Notification.Name("queuePasteHUDDismissRequested")
}

// MARK: - Non-activating NSPanel (no title bar / traffic lights — close is in-panel)

final class HUDPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 260),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        self.contentView = contentView
    }
}

// MARK: - HUD Window Coordinator

@MainActor
class HUDWindowController: NSObject {
    private var panel: HUDPanel?
    private var hostingView: NSHostingView<AnyView>?

    func show<Content: View>(content: Content) {
        if panel == nil {
            let hosting = NSHostingView(rootView: AnyView(content))
            hosting.wantsLayer = true
            let corner: CGFloat = 20
            hosting.layer?.cornerRadius = corner
            hosting.layer?.masksToBounds = true
            let newPanel = HUDPanel(contentView: hosting)
            newPanel.setFrameAutosaveName("QueuePasteHUD")
            if newPanel.frame.origin == .zero {
                if let screen = NSScreen.main {
                    let margin: CGFloat = 24
                    let frame = newPanel.frame
                    let origin = NSPoint(
                        x: screen.visibleFrame.maxX - frame.width - margin,
                        y: screen.visibleFrame.minY + margin
                    )
                    newPanel.setFrameOrigin(origin)
                }
            }
            panel = newPanel
            hostingView = hosting
        } else {
            update(content: content)
        }
        panel?.orderFront(nil)
    }

    func update<Content: View>(content: Content) {
        hostingView?.rootView = AnyView(content)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

// MARK: - SwiftUI HUD Container

struct HUDContainerView: View {
    @Environment(QueueViewModel.self) var vm
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let hudCorner: CGFloat = 20

    var body: some View {
        HUDPanelContent()
            .frame(minWidth: 296, idealWidth: 324, maxWidth: 400)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: hudCorner, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                } else {
                    ZStack {
                        // Most see-through system blur — avoid heavy milky overlays.
                        RoundedRectangle(cornerRadius: hudCorner, style: .continuous)
                            .fill(.ultraThinMaterial)
                        // Whisper of specular lift (was 14% white + overlay = too frosted).
                        RoundedRectangle(cornerRadius: hudCorner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.045),
                                        Color.white.opacity(0.0),
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .blendMode(.softLight)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: hudCorner, style: .continuous))
            // Lighter shadow so the panel feels airy, not like a card slab.
            .shadow(color: .black.opacity(0.12), radius: 22, y: 10)
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}

// MARK: - HUD Host View (embeds in SwiftUI via NSViewControllerRepresentable)

struct HUDWindowBridge: View {
    @Environment(QueueViewModel.self) var vm
    @State private var controller = HUDWindowController()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: vm.isHUDVisible) { _, visible in
                if visible {
                    controller.show(content: HUDContainerView().environment(vm))
                } else {
                    controller.hide()
                }
            }
            .onChange(of: vm.pointer) { _, _ in
                if vm.isHUDVisible {
                    controller.update(content: HUDContainerView().environment(vm))
                }
            }
            .onChange(of: vm.state) { _, _ in
                if vm.isHUDVisible {
                    controller.update(content: HUDContainerView().environment(vm))
                }
            }
            .onChange(of: vm.hudExpanded) { _, _ in
                if vm.isHUDVisible {
                    controller.update(content: HUDContainerView().environment(vm))
                }
            }
            .onChange(of: vm.items.count) { _, _ in
                if vm.isHUDVisible {
                    controller.update(content: HUDContainerView().environment(vm))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .queuePasteHUDDismissRequested)) { _ in
                vm.isHUDVisible = false
                controller.hide()
            }
    }
}
