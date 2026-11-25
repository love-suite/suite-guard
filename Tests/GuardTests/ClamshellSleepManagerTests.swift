import Foundation
import Testing
@testable import ClamshellGuard

private func freshDefaults() -> UserDefaults {
    let name = "ClamshellSleepManagerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// The Mac's lid sleep in memory: the real IOPMrootDomain is never touched by tests.
private final class FakeClamshell: ClamshellSleepSwitch {
    var disabled = false
    var calls: [Bool] = []
    var accepts = true
    func setSleepDisabled(_ disabled: Bool) -> Bool {
        calls.append(disabled)
        if accepts { self.disabled = disabled }
        return accepts
    }
}

@Suite struct ClamshellSleepManagerTests {
    @Test func turningOffNotesItFirst() {
        let lid = FakeClamshell()
        let memory = freshDefaults()
        let manager = ClamshellSleepManager(control: lid, memory: memory)
        #expect(manager.turnOff())
        #expect(lid.disabled)
        #expect(manager.isHiding)
        #expect(memory.bool(forKey: GuardedApps.clamshellMemoryKey))
    }

    @Test func restoringTurnsLidSleepBackOn() {
        let lid = FakeClamshell()
        let manager = ClamshellSleepManager(control: lid, memory: freshDefaults())
        manager.turnOff()
        manager.restore()
        #expect(!lid.disabled)
        #expect(!manager.isHiding)
    }

    /// Lid sleep that Awake didn't turn off (another app's, or the user's) is left alone.
    @Test func restoringWithNothingNotedChangesNothing() {
        let lid = FakeClamshell()
        lid.disabled = true
        let manager = ClamshellSleepManager(control: lid, memory: freshDefaults())
        manager.restore()
        #expect(lid.disabled)
        #expect(lid.calls.isEmpty)
    }

    /// Turned off again after a power change (powerd turns it back on): restoring once is enough.
    @Test func turningOffAgainThenRestoring() {
        let lid = FakeClamshell()
        let manager = ClamshellSleepManager(control: lid, memory: freshDefaults())
        manager.turnOff()
        manager.turnOff()
        manager.restore()
        #expect(lid.calls == [true, true, false])
        #expect(!manager.isHiding)
    }

    /// Refused by macOS, it is still noted: Suite Guard then turns it on, which changes nothing.
    @Test func aRefusedSwitchIsReportedAndStillNoted() {
        let lid = FakeClamshell()
        lid.accepts = false
        let manager = ClamshellSleepManager(control: lid, memory: freshDefaults())
        #expect(!manager.turnOff())
        #expect(manager.isHiding)
    }

    @Test func savedKeyIsWhatTheGuardReads() {
        #expect(ClamshellSleepManager.savedKey == GuardedApps.clamshellMemoryKey)
    }
}

@Suite struct ClamshellGuardRuleTests {
    let rule = ClamshellGuardRule()
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func lidSleepComesBackOnceAwakeIsGone() {
        #expect(!rule.shouldRestore(ownerRunning: true, hidden: true, lastSeen: start, started: start,
                                    now: start + 600))
        #expect(!rule.shouldRestore(ownerRunning: false, hidden: true, lastSeen: start, started: start - 100,
                                    now: start + 5))
        #expect(rule.shouldRestore(ownerRunning: false, hidden: true, lastSeen: start, started: start - 100,
                                   now: start + 15))
    }

    @Test func awakeIsFoundByItsExecutable() {
        #expect("/Users/me/Applications/Awake.app/Contents/MacOS/Awake".hasSuffix(GuardedApps.awakeExecutable))
    }
}
