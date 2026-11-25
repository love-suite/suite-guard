import Darwin
import Foundation

/// When Suite Guard puts back what an app hid (the system Dock, Finder's desktop): only while it is
/// hidden, once the app that hid it has been gone long enough that it isn't merely relaunching (an update,
/// Reopen), longer just after login, when the app may still be starting.
public struct GuardRule: Equatable, Sendable {
    /// How long the app may be gone before what it hid comes back.
    public var grace: TimeInterval = 15
    /// Just after the guard starts (at login), the app gets this long to show up.
    public var startGrace: TimeInterval = 90

    public init(grace: TimeInterval = 15, startGrace: TimeInterval = 90) {
        self.grace = grace
        self.startGrace = startGrace
    }

    /// `lastSeen`: when the app was last running (nil: not since the guard started at `started`).
    public func shouldRestore(ownerRunning: Bool, hidden: Bool, lastSeen: Date?, started: Date,
                              now: Date = Date()) -> Bool {
        guard hidden, !ownerRunning else { return false }
        if let lastSeen { return now.timeIntervalSince(lastSeen) >= grace }
        return now.timeIntervalSince(started) >= startGrace
    }
}

/// Processes running for this user, read from the system's process list (a process without windows doesn't
/// get NSWorkspace's running apps refreshed).
public enum RunningProcesses {
    /// A process whose executable path ends with `suffix` (".app/Contents/MacOS/Explorer").
    public static func contains(executableSuffix suffix: String) -> Bool {
        var pids = [pid_t](repeating: 0, count: 4096)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var path = [CChar](repeating: 0, count: 4096)
        for pid in pids.prefix(max(count, 0)) where pid > 0 {
            guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { continue }
            if String(cString: path).hasSuffix(suffix) { return true }
        }
        return false
    }
}
