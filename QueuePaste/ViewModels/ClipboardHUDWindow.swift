import AppKit
import SwiftUI
import AppKit

/// Floating panel window that hosts the clipboard HUD
@MainActor
final class ClipboardHUDWindow: NSPanel {
    
    private var hostingView: NSView?
    private let viewModel: ClipboardHUDViewModel
    private var eventMonitor: Any?
    
    init(viewModel: ClipboardHUDViewModel) {
        self.viewModel = viewModel
        
        // Calculate initial position
        let contentRect = NSRect(x: 0, y: 0, width: 700, height: 200)
        
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent()
        setupEventMonitoring()
    }
    
    private func setupWindow() {
        // Window behavior
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        // Interaction
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        
        // Position at bottom-center of main screen
        positionWindow()
    }
    
    private func setupContent() {
        let hudView = ClipboardHUDView()
            .environment(viewModel)
        
        let hosting = NSHostingView(rootView: hudView)
        hosting.frame = contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        
        contentView = hosting
        hostingView = hosting
    }
    
    private func setupEventMonitoring() {
        // Monitor for clicks outside the window to dismiss
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            
            let location = event.locationInWindow
            let windowFrame = self.frame
            let screenLocation = NSEvent.mouseLocation
            
            // Check if click is outside our window
            if !windowFrame.contains(screenLocation) {
                self.hide()
                return event
            }
            
            return event
        }
    }
    
    func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        // Check if we have a saved position
        if let savedPos = viewModel.savedPosition {
            // Validate it's still on screen
            let newFrame = NSRect(origin: savedPos, size: frame.size)
            if screen.visibleFrame.contains(newFrame) {
                setFrameOrigin(savedPos)
                return
            }
        }
        
        // Default to bottom-center
        let screenFrame = screen.visibleFrame
        let windowSize = frame.size
        
        let x = screenFrame.midX - (windowSize.width / 2)
        let y = screenFrame.minY + 80 // 80pt from bottom
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func show() {
        viewModel.show()
        positionWindow()
        
        // Animate appearance
        alphaValue = 0
        orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1.0
        }
        
        // Make window key to receive keyboard events
        makeKey()
    }
    
    func hide() {
        // Save position if user moved it
        if viewModel.rememberPosition {
            viewModel.savedPosition = frame.origin
        }
        
        // Animate disappearance
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.viewModel.hide()
        })
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape
            hide()
            
        case 123: // Left arrow
            viewModel.selectPrevious()
            
        case 124: // Right arrow
            viewModel.selectNext()
            
        case 36: // Return
            viewModel.pasteSelectedItem()
            
        case 49: // Space
            viewModel.pasteSelectedItem()
            
        case 51: // Delete (Backspace)
            viewModel.deleteSelectedItem()
            
        case 117: // Forward Delete
            viewModel.deleteSelectedItem()
            
        default:
            super.keyDown(with: event)
        }
    }
    
    // Save position when user drags window
    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(point)
        if viewModel.rememberPosition && isVisible {
            viewModel.savedPosition = point
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Coordinator for Managing HUD Instance

@MainActor
final class ClipboardHUDCoordinator {
    static let shared = ClipboardHUDCoordinator()
    
    private var hudWindow: ClipboardHUDWindow?
    private let viewModel = ClipboardHUDViewModel()
    
    private init() {
        // Listen for inbox changes to refresh HUD
        NotificationCenter.default.addObserver(
            forName: .queuePasteInboxDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.loadRecentItems()
        }
    }
    
    func toggle() {
        if let window = hudWindow, window.isVisible {
            window.hide()
        } else {
            showHUD()
        }
    }
    
    func showHUD() {
        if hudWindow == nil {
            hudWindow = ClipboardHUDWindow(viewModel: viewModel)
        }
        
        hudWindow?.show()
    }
    
    func hideHUD() {
        hudWindow?.hide()
    }
}
