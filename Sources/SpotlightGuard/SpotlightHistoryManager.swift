import Foundation
@_exported import GuardCore

/// When Spotlight's clipboard history comes back: Clipboard, which turns it off, gone.
public typealias SpotlightGuardRule = GuardRule

/// Spotlight's own clipboard history (macOS 26, Spotlight's public `PasteboardHistoryEnabled` setting),
/// which Clipboard turns off while it runs, so the two don't both keep the copies. Spotlight's own setting
/// from before is kept in Clipboard's preferences, so the history comes back as the user had it, even after
/// a crash, when Suite Guard puts it back.
public final class SpotlightHistoryManager {
    public static let spotlightDomain = "com.apple.Spotlight"
    public static let key = "PasteboardHistoryEnabled"
    /// The key, in Clipboard's preferences, holding Spotlight's own setting while its history is off:
    /// "on", "off", or "none" when the user never set it.
    public static let savedKey = "SpotlightHistoryBefore"

    private let spotlight: PreferenceDomain
    private let memory: UserDefaults

    public init(spotlight: PreferenceDomain = AppPreferenceDomain(SpotlightHistoryManager.spotlightDomain),
                memory: UserDefaults = .standard) {
        self.spotlight = spotlight
        self.memory = memory
    }

    /// True while Spotlight's history is off because of us: Spotlight's own setting is kept.
    public var isHiding: Bool { memory.string(forKey: Self.savedKey) != nil }

    /// Turns Spotlight's history off, keeping Spotlight's own setting first (once: turning off again keeps
    /// the first).
    public func turnOff() {
        if !isHiding {
            let current = spotlight.value(forKey: Self.key) as? Bool
            memory.set(current.map { $0 ? "on" : "off" } ?? "none", forKey: Self.savedKey)
        }
        spotlight.setValue(false, forKey: Self.key)
    }

    /// Spotlight's history as the user had it.
    public func restore() {
        guard let saved = memory.string(forKey: Self.savedKey) else { return }
        let value: Bool? = switch saved {
        case "on": true
        case "off": false
        default: nil
        }
        spotlight.setValue(value, forKey: Self.key)
        memory.removeObject(forKey: Self.savedKey)
    }
}
