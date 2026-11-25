import AppKit
import ClamshellGuard
import DockGuard
import FinderGuard
import SpotlightGuard
import SuiteCore

// Suite Guard: a small agent of the user's session (launchd, loaded by the app that hides something, see
// `GuardAgent`), while the system Dock, Finder's desktop or Spotlight's clipboard history is hidden, or
// lid sleep is off. It
// only watches: if the app that hid one is gone and doesn't come back (a crash, a forced quit, not started
// at login), it puts it back: the system Dock from the copy that app kept, Finder's desktop (Finder
// restarted or started), Spotlight's history as the user had it, lid sleep turned back on (a Mac never left awake in a bag),
// so the Mac is never left without them. It does nothing while those apps run.
let dock = DockManager(memory: GuardedApps.barDefaults, restartDock: {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
    process.arguments = ["Dock"]
    try? process.run()
    process.waitUntilExit()
})
let finder = FinderManager(memory: GuardedApps.desktopDefaults)
let dockRule = DockGuardRule()
let finderRule = FinderGuardRule()
let spotlight = SpotlightHistoryManager(memory: GuardedApps.clipboardDefaults)
let spotlightRule = SpotlightGuardRule()
let started = Date()
var barSeen: Date?
var desktopOwnerSeen: Date?
var clipboardSeen: Date?
let clamshell = ClamshellSleepManager(memory: GuardedApps.awakeDefaults)
let clamshellRule = ClamshellGuardRule()
var awakeSeen: Date?

Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
    let barRunning = RunningProcesses.contains(executableSuffix: GuardedApps.barExecutable)
    let desktopOwnerRunning = RunningProcesses.contains(executableSuffix: GuardedApps.desktopExecutable)
    let clipboardRunning = RunningProcesses.contains(executableSuffix: GuardedApps.clipboardExecutable)
    if barRunning { barSeen = Date() }
    if desktopOwnerRunning { desktopOwnerSeen = Date() }
    if clipboardRunning { clipboardSeen = Date() }
    let awakeRunning = RunningProcesses.contains(executableSuffix: GuardedApps.awakeExecutable)
    if awakeRunning { awakeSeen = Date() }
    if dockRule.shouldRestore(ownerRunning: barRunning, hidden: GuardedApps.systemDockHidden,
                              lastSeen: barSeen, started: started) {
        FileHandle.standardError.write(Data("Suite Guard: our Dock is gone, putting the system Dock back\n".utf8))
        dock.restore()
    }
    if finderRule.shouldRestore(ownerRunning: desktopOwnerRunning, hidden: GuardedApps.finderDesktopHidden,
                                lastSeen: desktopOwnerSeen, started: started) {
        FileHandle.standardError.write(Data("Suite Guard: Desktop is gone, putting Finder's desktop back\n".utf8))
        finder.restore()
    }
    if spotlightRule.shouldRestore(ownerRunning: clipboardRunning, hidden: GuardedApps.spotlightHistoryHidden,
                                   lastSeen: clipboardSeen, started: started) {
        FileHandle.standardError.write(Data("Suite Guard: Clipboard is gone, putting Spotlight's clipboard history back\n".utf8))
        spotlight.restore()
    }
    if clamshellRule.shouldRestore(ownerRunning: awakeRunning, hidden: GuardedApps.clamshellSleepDisabled,
                                   lastSeen: awakeSeen, started: started) {
        FileHandle.standardError.write(Data("Suite Guard: Awake is gone, turning lid sleep back on\n".utf8))
        clamshell.restore()
    }
}
// Suite Guard keeps itself up to date from its own releases, quietly (no window to ask in): once the new
// copy is in place it leaves, and launchd starts it again from there.
let updater = SuiteUpdater(appName: "Suite Guard", isBusy: { false }, quiet: true, relaunch: { exit(0) })
updater.start()

RunLoop.main.run()
