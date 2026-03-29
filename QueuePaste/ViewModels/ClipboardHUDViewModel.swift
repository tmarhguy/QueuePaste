import AppKit
import AppKit
import SwiftUI
import Observation

/// Layout options for the HUD
enum HUDLayout: String, CaseIterable, Codable {
    case horizontal
    case vertical
    
    var displayName: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Grid"
        }
    }
    
    var icon: String {
        switch self {
        case .horizontal: return "rectangle.split.3x1"
        case .vertical: return "square.grid.2x2"
        }
    }
}

/// View model managing state for the universal floating clipboard HUD
@Observable
@MainActor
final class ClipboardHUDViewModel {
    
    // MARK: - State
    
    var isVisible = false
    var recentItems: [InboxRow] = []
    var selectedIndex: Int = 0
    var hoveredIndex: Int? = nil
    
    // User preferences
    var maxVisibleItems = 8
    var autoPasteOnClick = true
    var rememberPosition = true
    var layout: HUDLayout {
        get {
            if let saved = UserDefaults.standard.string(forKey: "ClipboardHUDLayout"),
               let layout = HUDLayout(rawValue: saved) {
                return layout
            }
            return .horizontal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ClipboardHUDLayout")
        }
    }
    
    // Window position
    var savedPosition: CGPoint? {
        get {
            guard rememberPosition else { return nil }
            guard let data = UserDefaults.standard.data(forKey: "ClipboardHUDPosition"),
                  let point = try? JSONDecoder().decode(CGPoint.self, from: data) else {
                return nil
            }
            return point
        }
        set {
            guard rememberPosition, let newValue else {
                UserDefaults.standard.removeObject(forKey: "ClipboardHUDPosition")
                return
            }
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "ClipboardHUDPosition")
            }
        }
    }
    
    // MARK: - Lifecycle
    
    func show() {
        loadRecentItems()
        selectedIndex = 0
        isVisible = true
    }
    
    func hide() {
        isVisible = false
        hoveredIndex = nil
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - Data Loading
    
    func loadRecentItems() {
        do {
            // Get recent items, prioritizing pinned items
            let allItems = try InboxStore.shared.inboxRows(search: nil, filter: .all)
            
            // Take pinned first, then most recent, up to maxVisibleItems
            let pinned = allItems.filter { $0.pinned }
            let unpinned = allItems.filter { !$0.pinned }
            
            var combined = pinned + unpinned
            if combined.count > maxVisibleItems {
                combined = Array(combined.prefix(maxVisibleItems))
            }
            
            recentItems = combined
        } catch {
            print("Failed to load recent items: \(error)")
            recentItems = []
        }
    }
    
    // MARK: - Selection & Navigation
    
    func selectNext() {
        guard !recentItems.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % recentItems.count
    }
    
    func selectPrevious() {
        guard !recentItems.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + recentItems.count) % recentItems.count
    }
    
    func selectItem(at index: Int) {
        guard index >= 0 && index < recentItems.count else { return }
        selectedIndex = index
    }
    
    // MARK: - Actions
    
    func pasteSelectedItem() {
        guard selectedIndex < recentItems.count else { return }
        let item = recentItems[selectedIndex]
        pasteItem(item)
    }
    
    func pasteItem(_ item: InboxRow) {
        do {
            // Check if this item is already on the clipboard
            let isAlreadyOnClipboard = checkIfItemOnClipboard(item)
            
            if !isAlreadyOnClipboard {
                // Copy to clipboard only if different
                try InboxStore.shared.copyInboxItemToPasteboard(id: item.id)
                
                // Auto-paste if enabled
                if autoPasteOnClick {
                    // Small delay to ensure clipboard is updated
                    Task {
                        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                        await MainActor.run {
                            if AccessibilityService.isTrusted() {
                                PasteService.paste()
                            }
                        }
                    }
                }
            } else {
                // Item already on clipboard, just paste
                if autoPasteOnClick && AccessibilityService.isTrusted() {
                    PasteService.paste()
                }
            }
            
            hide()
        } catch {
            print("Failed to paste item: \(error)")
        }
    }
    
    /// Check if the given item is currently on the clipboard
    private func checkIfItemOnClipboard(_ item: InboxRow) -> Bool {
        let pb = NSPasteboard.general
        
        switch item.kind {
        case .text:
            if let clipText = pb.string(forType: .string),
               let itemText = item.textContent {
                return clipText == itemText
            }
            return false
            
        case .image:
            // For images, compare by hash
            if let _ = NSImage(pasteboard: pb) {
                // Generate hash of current clipboard image
                if let currentImageData = pb.data(forType: .tiff) {
                    let currentHash = Self.hashData(currentImageData)
                    return currentHash == item.contentHash
                }
            }
            return false
        }
    }
    
    /// Hash data for comparison
    private static func hashData(_ data: Data) -> String {
        let hash = data.withUnsafeBytes { ptr -> String in
            var hasher = Hasher()
            hasher.combine(bytes: UnsafeRawBufferPointer(start: ptr.baseAddress, count: data.count))
            return String(hasher.finalize())
        }
        return hash
    }
    
    func copyItem(_ item: InboxRow) {
        do {
            try InboxStore.shared.copyInboxItemToPasteboard(id: item.id)
            hide()
        } catch {
            print("Failed to copy item: \(error)")
        }
    }
    
    func deleteSelectedItem() {
        guard selectedIndex < recentItems.count else { return }
        let item = recentItems[selectedIndex]
        deleteItem(item)
    }
    
    func deleteItem(_ item: InboxRow) {
        do {
            try InboxStore.shared.deleteInboxItem(id: item.id)
            
            // Reload items
            loadRecentItems()
            
            // Adjust selected index if needed
            if selectedIndex >= recentItems.count && !recentItems.isEmpty {
                selectedIndex = recentItems.count - 1
            } else if recentItems.isEmpty {
                selectedIndex = 0
            }
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
}

// MARK: - CGPoint Codable Extension

extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
}
