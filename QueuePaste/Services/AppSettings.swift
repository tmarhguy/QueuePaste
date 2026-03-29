import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key: String {
        case passiveCaptureEnabled
        case capturePaused
        case captureOnboardingShown
        case capturePauseUntil
        case ignoredBundleIds
        case pauseTimerMinutes
        case aggressiveCaptureMode
        case captureDeduplication
    }

    /// Default caps per product spec (update2 §9).
    static let maxInboxItems = 500
    static let maxInboxBytes = 250 * 1024 * 1024

    var passiveCaptureEnabled: Bool {
        get { defaults.bool(forKey: Key.passiveCaptureEnabled.rawValue) }
        set { defaults.set(newValue, forKey: Key.passiveCaptureEnabled.rawValue) }
    }

    var capturePaused: Bool {
        get { defaults.bool(forKey: Key.capturePaused.rawValue) }
        set { defaults.set(newValue, forKey: Key.capturePaused.rawValue) }
    }

    var captureOnboardingShown: Bool {
        get { defaults.bool(forKey: Key.captureOnboardingShown.rawValue) }
        set { defaults.set(newValue, forKey: Key.captureOnboardingShown.rawValue) }
    }

    /// When set and `Date() < capturePauseUntil`, passive capture stays off until time elapses.
    var capturePauseUntil: Date? {
        get { defaults.object(forKey: Key.capturePauseUntil.rawValue) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.capturePauseUntil.rawValue)
            } else {
                defaults.removeObject(forKey: Key.capturePauseUntil.rawValue)
            }
        }
    }

    var ignoredBundleIds: [String] {
        get { defaults.stringArray(forKey: Key.ignoredBundleIds.rawValue) ?? [] }
        set { defaults.set(newValue, forKey: Key.ignoredBundleIds.rawValue) }
    }

    /// 0 = no auto-resume timer.
    var pauseTimerMinutes: Int {
        get {
            let v = defaults.integer(forKey: Key.pauseTimerMinutes.rawValue)
            return max(0, min(240, v))
        }
        set { defaults.set(max(0, min(240, newValue)), forKey: Key.pauseTimerMinutes.rawValue) }
    }

    func effectiveCapturePaused(now: Date = .now) -> Bool {
        if capturePaused { return true }
        if let until = capturePauseUntil, now < until { return true }
        return false
    }

    func clearTimedPauseIfExpired(now: Date = .now) {
        if let until = capturePauseUntil, now >= until {
            capturePauseUntil = nil
            capturePaused = false
        }
    }
    
    /// When enabled, capture everything including duplicates (for true dump mode)
    var aggressiveCaptureMode: Bool {
        get { defaults.bool(forKey: Key.aggressiveCaptureMode.rawValue) }
        set { defaults.set(newValue, forKey: Key.aggressiveCaptureMode.rawValue) }
    }
    
    /// When disabled, every clipboard change is captured even if it's a duplicate
    var captureDeduplication: Bool {
        get {
            // Default to true if not set
            if defaults.object(forKey: Key.captureDeduplication.rawValue) == nil {
                return true
            }
            return defaults.bool(forKey: Key.captureDeduplication.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.captureDeduplication.rawValue) }
    }
}
