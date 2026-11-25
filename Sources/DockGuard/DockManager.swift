import Foundation
@_exported import GuardCore

// Hiding the system Dock, and putting it back: our Dock hides it while it is shown, Suite Guard puts it
// back should our Dock vanish.

/// When the system Dock comes back: the app showing our Dock gone.
public typealias DockGuardRule = GuardRule

/// Hides the system Dock with public settings only: automatic hiding with a delay so long it doesn't come
/// back, and an animation so slow that it wouldn't be seen if it did, then a Dock restart. The values
/// found before are kept in our own preferences, so they can be put back even after a crash.
public final class DockManager {
    /// The system Dock's preferences domain.
    public static let dockDomain = "com.apple.dock"
    /// What the Dock is set to while hidden.
    public static let hiddenSettings: [(key: String, value: Any)] = [
        ("autohide", true),
        // Seconds before the hidden Dock would show: longer than anyone hovers.
        ("autohide-delay", 1000.0),
        // Seconds the sliding in would take, should the Dock still decide to show (pushing at the edge).
        ("autohide-time-modifier", 1000.0),
        // At the bottom, where windows minimize to (the animation follows the hidden Dock), with the
        // running apps only and icons of a single point (the preferences take 1, below System Settings'
        // 16: tested on macOS 27), so it is a sliver even in Mission Control and the stretch of the bottom
        // edge where it wakes up is as short as can be.
        ("tilesize", 1.0),
        ("orientation", "bottom"),
        ("static-only", true),
    ]
    private static let savedKey = GuardedApps.dockMemoryKey

    private let dock: PreferenceDomain
    private let memory: UserDefaults
    private let restartDock: () -> Void

    public init(dock: PreferenceDomain = AppPreferenceDomain(DockManager.dockDomain),
                memory: UserDefaults = .standard, restartDock: @escaping () -> Void) {
        self.dock = dock
        self.memory = memory
        self.restartDock = restartDock
    }

    /// True while the system Dock is hidden by us (and its previous settings are kept).
    public var isHiding: Bool { memory.dictionary(forKey: Self.savedKey) != nil }

    private var isHiddenNow: Bool {
        Self.hiddenSettings.allSatisfy { key, value in
            (dock.value(forKey: key) as? NSObject)?.isEqual(value) == true
        }
    }

    /// Hides the system Dock; does nothing (no restart) if it already is.
    public func hide() {
        var saved = memory.dictionary(forKey: Self.savedKey) ?? [:]
        var missing = !isHiding
        // Each key saved is marked, so a key added by a later version is saved once, before it changes.
        for (key, _) in Self.hiddenSettings where saved["~" + key] == nil {
            if let value = dock.value(forKey: key) { saved[key] = value }
            saved["~" + key] = true
            missing = true
        }
        if missing { memory.set(saved, forKey: Self.savedKey) }
        guard !isHiddenNow else { return }
        for (key, value) in Self.hiddenSettings { dock.setValue(value, forKey: key) }
        restartDock()
    }

    /// The values the system Dock takes when it is put back, in place of those found before hiding: our
    /// Dock's own, for the settings both have (its size, its automatic hiding), so a user going back to
    /// the system Dock keeps them. Kept with the saved settings, so Suite Guard carries them too.
    public func carry(_ values: [String: Any]) {
        guard var saved = memory.dictionary(forKey: Self.savedKey) else { return }
        for (key, value) in values { saved[key] = value }
        memory.set(saved, forKey: Self.savedKey)
    }

    /// Puts back the settings found before hiding (or carried since); does nothing if we didn't hide it.
    public func restore() {
        guard let saved = memory.dictionary(forKey: Self.savedKey) else { return }
        for (key, _) in Self.hiddenSettings {
            dock.setValue(saved[key], forKey: key)
        }
        memory.removeObject(forKey: Self.savedKey)
        restartDock()
    }
}
