import AppKit
import Foundation
import ServiceManagement

/// Suite Guard (Suite Guard.app), a launch agent of the user's session while the system Dock, Finder's
/// desktop or Spotlight's clipboard history is hidden, or lid sleep is off: if the app that hid it crashes, is forced to quit or isn't started at login, the
/// guard puts it back. Removed once nothing is hidden. Every app that hides something calls `update()`
/// after hiding or showing; each sees the same state, so whichever calls last is right.
///
/// A plain launch agent (`~/Library/LaunchAgents`, loaded with `launchctl`) that runs Suite Guard.app's
/// executable by its path. Registered through SMAppService instead, launchd held the guard to the code
/// signature of an earlier build, our signing certificate not being Apple's, and refused to start it after
/// most updates.
public enum GuardAgent {
    public static let label = "local.suite.guard"

    private static func plistURL(_ label: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    private static var plistURL: URL { plistURL(label) }

    private static var domain: String { "gui/\(getuid())" }
    private static var service: String { "\(domain)/\(label)" }

    /// The build whose guard runs: after an update, the guard is started again from the new one.
    private static let buildKey = "SuiteGuardRegisteredBuild"
    private static var build: String {
        guardApp.flatMap { Bundle(url: $0)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String } ?? ""
    }

    /// Suite Guard.app, wherever Launch Services knows it (`~/Applications` by default).
    public static var guardApp: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: GuardedApps.guardBundleID)
    }

    /// Running while the system Dock, Finder's desktop or Spotlight's clipboard history is hidden, or lid
    /// sleep is off, not otherwise.
    public static func update() {
        setRegistered(GuardedApps.systemDockHidden || GuardedApps.finderDesktopHidden
                      || GuardedApps.spotlightHistoryHidden || GuardedApps.clamshellSleepDisabled)
    }

    public static func setRegistered(_ registered: Bool) {
        registered ? install() : remove(label: label)
    }

    private static func install() {
        guard let app = guardApp, let executable = Bundle(url: app)?.executableURL else {
            report("isn't installed: nothing will put back what this app hides should it vanish")
            return
        }
        let program = executable.path
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [program],
            // Running from login, and again should it ever stop.
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        else { return }
        let changed = (try? Data(contentsOf: plistURL)) != data
        if changed {
            do {
                try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: plistURL, options: .atomic)
            } catch {
                report("couldn't be written: \(error)")
                return
            }
        }
        let loaded = launchctl("print", service) == 0
        if loaded, changed {
            launchctl("bootout", service)
        }
        if !loaded || changed {
            if launchctl("bootstrap", domain, plistURL.path) != 0 { report("couldn't be started") }
        } else if UserDefaults.standard.string(forKey: buildKey) != build {
            // An update: the guard starts again from the new build.
            launchctl("kickstart", "-k", service)
        }
        UserDefaults.standard.set(build, forKey: buildKey)
    }

    private static func remove(label: String) {
        let service = "\(domain)/\(label)"
        if launchctl("print", service) == 0 {
            launchctl("bootout", service)
        }
        let plist = plistURL(label)
        if FileManager.default.fileExists(atPath: plist.path) {
            try? FileManager.default.removeItem(at: plist)
        }
    }

    @discardableResult
    private static func launchctl(_ arguments: String...) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }

    private static func report(_ message: String) {
        FileHandle.standardError.write(Data("Suite Guard \(message)\n".utf8))
    }
}
