@testable import DockGuard
import GuardCore
import Foundation
import Testing

@Suite struct BarGuardTests {
    let guardian = GuardRule(grace: 15, startGrace: 90)
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func nothingWhileExplorerRunsOrTheDockShows() {
        #expect(!guardian.shouldRestore(ownerRunning: true, hidden: true, lastSeen: start, started: start,
                                        now: start + 600))
        #expect(!guardian.shouldRestore(ownerRunning: false, hidden: false, lastSeen: start, started: start,
                                        now: start + 600))
    }

    @Test func aRelaunchIsWaitedFor() {
        // Gone 5 seconds (an update relaunching): still hidden; gone 15: the Dock comes back.
        #expect(!guardian.shouldRestore(ownerRunning: false, hidden: true, lastSeen: start, started: start - 100,
                                        now: start + 5))
        #expect(guardian.shouldRestore(ownerRunning: false, hidden: true, lastSeen: start, started: start - 100,
                                       now: start + 15))
    }

    @Test func atLoginExplorerGetsLongerToStart() {
        #expect(!guardian.shouldRestore(ownerRunning: false, hidden: true, lastSeen: nil, started: start,
                                        now: start + 60))
        #expect(guardian.shouldRestore(ownerRunning: false, hidden: true, lastSeen: nil, started: start,
                                       now: start + 90))
    }
}

@Suite struct GuardedAppsTests {
    @Test func ourDockIsNeverTakenForTheSystemDock() {
        #expect(!"/System/Library/CoreServices/Dock.app/Contents/MacOS/Dock".hasSuffix(GuardedApps.barExecutable))
        #expect("/Users/me/Applications/Bar.app/Contents/MacOS/Bar".hasSuffix(GuardedApps.barExecutable))
    }
}
