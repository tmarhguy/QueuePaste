import Foundation

enum QueueState: String, Equatable, Codable {
    case idle       // No queue loaded
    case ready      // Queue loaded, not started
    case active     // Running — hotkeys operate
    case paused     // Hotkeys disabled, HUD shows paused
    case complete   // All items pasted

    var displayName: String {
        switch self {
        case .idle:     return "Idle"
        case .ready:    return "Ready"
        case .active:   return "Active"
        case .paused:   return "Paused"
        case .complete: return "Complete"
        }
    }

    var color: String {
        switch self {
        case .idle:     return "gray"
        case .ready:    return "blue"
        case .active:   return "green"
        case .paused:   return "orange"
        case .complete: return "purple"
        }
    }
}
