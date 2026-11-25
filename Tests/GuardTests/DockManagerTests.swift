import Foundation
import Testing
@testable import DockGuard

private func freshDefaults() -> UserDefaults {
    let name = "SystemDockManagerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// A Dock preferences domain in memory: the real Dock is never touched by tests.
private final class FakeDock: PreferenceDomain {
    var values: [String: Any]
    init(_ values: [String: Any] = [:]) { self.values = values }
    func value(forKey key: String) -> Any? { values[key] }
    func setValue(_ value: Any?, forKey key: String) { values[key] = value }
}

@Suite struct DockManagerTests {
    @Test func hidingSetsALongDelayAndSlowAnimationAndRestartsTheDock() {
        let dock = FakeDock(["autohide": false])
        var restarts = 0
        let hider = DockManager(dock: dock, memory: freshDefaults(), restartDock: { restarts += 1 })
        hider.hide()
        #expect(dock.values["autohide"] as? Bool == true)
        #expect(dock.values["autohide-delay"] as? Double == 1000)
        #expect(dock.values["autohide-time-modifier"] as? Double == 1000)
        #expect(dock.values["tilesize"] as? Double == 1)
        #expect(dock.values["orientation"] as? String == "bottom")
        #expect(dock.values["static-only"] as? Bool == true)
        #expect(restarts == 1)
        #expect(hider.isHiding)
    }

    @Test func restoringPutsBackTheValuesFoundBefore() {
        let dock = FakeDock(["autohide": false, "autohide-time-modifier": 0.2, "tilesize": 36,
                             "orientation": "left"])
        var restarts = 0
        let hider = DockManager(dock: dock, memory: freshDefaults(), restartDock: { restarts += 1 })
        hider.hide()
        hider.restore()
        #expect(dock.values["autohide"] as? Bool == false)
        #expect(dock.values["autohide-time-modifier"] as? Double == 0.2)
        #expect(dock.values["tilesize"] as? Int == 36)
        #expect(dock.values["orientation"] as? String == "left")
        #expect(dock.values["static-only"] == nil)
        // The delay wasn't set before, so it is removed rather than set to a value of ours.
        #expect(dock.values["autohide-delay"] == nil)
        #expect(!hider.isHiding)
        #expect(restarts == 2)
    }

    @Test func hidingTwiceKeepsTheFirstValuesAndDoesntRestartAgain() {
        let dock = FakeDock(["autohide": true, "autohide-delay": 0.5])
        let memory = freshDefaults()
        var restarts = 0
        let hider = DockManager(dock: dock, memory: memory, restartDock: { restarts += 1 })
        hider.hide()
        hider.hide()
        #expect(restarts == 1)
        // Another launch after a crash: the saved values are still the user's.
        DockManager(dock: dock, memory: memory, restartDock: { restarts += 1 }).restore()
        #expect(dock.values["autohide"] as? Bool == true)
        #expect(dock.values["autohide-delay"] as? Double == 0.5)
        #expect(dock.values["autohide-time-modifier"] == nil)
    }

    @Test func restoringWithoutHidingDoesNothing() {
        let dock = FakeDock(["autohide": true])
        var restarts = 0
        DockManager(dock: dock, memory: freshDefaults(), restartDock: { restarts += 1 }).restore()
        #expect(dock.values["autohide"] as? Bool == true)
        #expect(restarts == 0)
    }

    @Test func carriedValuesComeBackInsteadOfTheOldOnes() {
        let dock = FakeDock(["autohide": false, "tilesize": 36])
        let hider = DockManager(dock: dock, memory: freshDefaults(), restartDock: {})
        hider.hide()
        hider.carry(["tilesize": 48.0, "autohide": true])
        hider.restore()
        #expect(dock.values["tilesize"] as? Double == 48)
        #expect(dock.values["autohide"] as? Bool == true)
        #expect(dock.values["autohide-delay"] == nil)
    }

    @Test func carryingWithoutHidingDoesNothing() {
        let memory = freshDefaults()
        let hider = DockManager(dock: FakeDock(), memory: memory, restartDock: {})
        hider.carry(["tilesize": 48.0])
        #expect(!hider.isHiding)
    }
}
