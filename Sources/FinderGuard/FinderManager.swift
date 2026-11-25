import Foundation
@_exported import GuardCore

/// When Finder's desktop comes back: Desktop, which hides it, gone.
public typealias FinderGuardRule = GuardRule

/// Finder's desktop (Finder's `CreateDesktop` setting), which Desktop hides while it shows its own. Finder's
/// own setting from before is kept in the desktop owner's preferences, so the desktop comes back as the
/// user had it (off stays off), even after a crash, when Suite Guard puts it back.
public final class FinderManager {
    public static let finderDomain = "com.apple.finder"
    public static let key = "CreateDesktop"
    /// The key, in the desktop owner's preferences, holding Finder's own setting while its desktop is hidden.
    public static let savedKey = "FinderDesktopBeforeHiding"

    private let finder: PreferenceDomain
    private let memory: UserDefaults
    private let restartFinder: () -> Void

    /// `restartFinder`: Finder reads the setting at launch, so it is restarted when running, started
    /// otherwise.
    public init(finder: PreferenceDomain = AppPreferenceDomain(FinderManager.finderDomain),
                memory: UserDefaults = .standard, restartFinder: @escaping () -> Void = FinderManager.restartOrStartFinder) {
        self.finder = finder
        self.memory = memory
        self.restartFinder = restartFinder
    }

    /// True while Finder's desktop is hidden by us: Finder's own setting is kept.
    public var isHiding: Bool { memory.object(forKey: Self.savedKey) != nil }

    /// Hides Finder's desktop, keeping Finder's own setting first (once: hiding again keeps the first).
    /// Already hidden (Desktop reopening itself), Finder isn't restarted again.
    public func hide() {
        if isHiding, finder.value(forKey: Self.key) as? Bool == false { return }
        if !isHiding { memory.set(finder.value(forKey: Self.key) as? Bool ?? true, forKey: Self.savedKey) }
        finder.setValue(false, forKey: Self.key)
        restartFinder()
    }

    /// Finder's desktop as the user had it, Finder restarted to show it.
    public func restore() {
        guard let shown = memory.object(forKey: Self.savedKey) as? Bool else { return }
        // Finder's default is a shown desktop: put the key back only when the user had turned it off.
        finder.setValue(shown ? nil : false, forKey: Self.key)
        memory.removeObject(forKey: Self.savedKey)
        restartFinder()
    }

    /// Restarts Finder when it runs, starts it otherwise (in the background).
    public static func restartOrStartFinder() {
        if RunningProcesses.contains(executableSuffix: "/Finder.app/Contents/MacOS/Finder") {
            run("/usr/bin/killall", ["Finder"])
        } else {
            run("/usr/bin/open", ["-g", "-b", finderDomain])
        }
    }

    private static func run(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}
