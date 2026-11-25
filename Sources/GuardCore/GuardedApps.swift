import Foundation

/// What Suite Guard watches: for each thing hidden, the app that hid it and where that app notes it.
public enum GuardedApps {
    /// Suite Guard's own app.
    public static let guardBundleID = "local.suite.guard"

    /// The app showing our Dock, which hides the system Dock: Bar.app. Its defaults keep the system Dock's
    /// settings from before hiding (Explorer's did, while the Dock was part of Explorer: Bar.app moves them).
    public static let barDomain = "local.suite.bar"
    /// Not "Dock": that is the system Dock's process (`/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock`),
    /// which `killall Dock` restarts.
    public static let barExecutable = "/Bar.app/Contents/MacOS/Bar"
    /// The key, in the Dock owner's defaults, holding the system Dock's settings while it is hidden.
    public static let dockMemoryKey = "DockSettingsBeforeHiding"

    /// The app showing our desktop, which hides Finder's: Desktop.app. Its defaults keep Finder's own
    /// setting from before hiding.
    public static let desktopDomain = "local.suite.desktop"
    public static let desktopExecutable = "/Desktop.app/Contents/MacOS/Desktop"
    /// The key, in the desktop owner's defaults, holding Finder's own setting while its desktop is hidden
    /// (`FinderManager.savedKey`).
    public static let finderMemoryKey = "FinderDesktopBeforeHiding"

    /// The app with our clipboard history, which turns Spotlight's off: Clipboard.app. Its defaults keep
    /// Spotlight's own setting from before (`SpotlightHistoryManager.savedKey`).
    public static let clipboardDomain = "local.suite.clipboard"
    public static let clipboardExecutable = "/Clipboard.app/Contents/MacOS/Clipboard"
    public static let spotlightMemoryKey = "SpotlightHistoryBefore"

    /// The app keeping the Mac awake, which turns lid sleep off during a closed-lid session: Awake.app. Its
    /// defaults note it while lid sleep is off (`ClamshellSleepManager.savedKey`).
    public static let awakeDomain = "local.suite.awake"
    public static let awakeExecutable = "/Awake.app/Contents/MacOS/Awake"
    public static let clamshellMemoryKey = "ClamshellSleepDisabledByAwake"

    /// The Dock owner's defaults, read from any app.
    public static var barDefaults: UserDefaults {
        Bundle.main.bundleIdentifier == barDomain ? .standard : UserDefaults(suiteName: barDomain) ?? .standard
    }

    /// True while the system Dock is hidden by us.
    public static var systemDockHidden: Bool {
        CFPreferencesAppSynchronize(barDomain as CFString)
        return barDefaults.dictionary(forKey: dockMemoryKey) != nil
    }

    /// The desktop owner's defaults, read from any app.
    public static var desktopDefaults: UserDefaults {
        Bundle.main.bundleIdentifier == desktopDomain ? .standard : UserDefaults(suiteName: desktopDomain) ?? .standard
    }

    /// True while Finder's desktop is hidden by us (the user turning it off in Finder doesn't count).
    public static var finderDesktopHidden: Bool {
        CFPreferencesAppSynchronize(desktopDomain as CFString)
        return desktopDefaults.object(forKey: finderMemoryKey) != nil
    }

    /// Clipboard's defaults, read from any app.
    public static var clipboardDefaults: UserDefaults {
        Bundle.main.bundleIdentifier == clipboardDomain ? .standard : UserDefaults(suiteName: clipboardDomain) ?? .standard
    }

    /// True while Spotlight's clipboard history is off because of Clipboard.
    public static var spotlightHistoryHidden: Bool {
        CFPreferencesAppSynchronize(clipboardDomain as CFString)
        return clipboardDefaults.string(forKey: spotlightMemoryKey) != nil
    }

    /// Awake's defaults, read from any app.
    public static var awakeDefaults: UserDefaults {
        Bundle.main.bundleIdentifier == awakeDomain ? .standard : UserDefaults(suiteName: awakeDomain) ?? .standard
    }

    /// True while closing the lid doesn't sleep the Mac because of Awake.
    public static var clamshellSleepDisabled: Bool {
        CFPreferencesAppSynchronize(awakeDomain as CFString)
        return awakeDefaults.bool(forKey: clamshellMemoryKey)
    }
}
