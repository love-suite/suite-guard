import Foundation
import Testing
@testable import FinderGuard

private func freshDefaults() -> UserDefaults {
    let name = "FinderManagerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// Finder's preferences domain in memory: the real Finder is never touched by tests.
private final class FakeFinder: PreferenceDomain {
    var values: [String: Any]
    init(_ values: [String: Any] = [:]) { self.values = values }
    func value(forKey key: String) -> Any? { values[key] }
    func setValue(_ value: Any?, forKey key: String) { values[key] = value }
}

@Suite struct FinderManagerTests {
    @Test func hidingTurnsTheDesktopOffAndRestartsFinder() {
        let finder = FakeFinder()
        var restarts = 0
        let manager = FinderManager(finder: finder, memory: freshDefaults(), restartFinder: { restarts += 1 })
        manager.hide()
        #expect(finder.values["CreateDesktop"] as? Bool == false)
        #expect(manager.isHiding)
        #expect(restarts == 1)
    }

    @Test func restoringPutsBackFindersDefault() {
        let finder = FakeFinder()
        let manager = FinderManager(finder: finder, memory: freshDefaults(), restartFinder: {})
        manager.hide()
        manager.restore()
        #expect(finder.values["CreateDesktop"] == nil)
        #expect(!manager.isHiding)
    }

    @Test func aDesktopTheUserTurnedOffStaysOff() {
        let finder = FakeFinder(["CreateDesktop": false])
        let manager = FinderManager(finder: finder, memory: freshDefaults(), restartFinder: {})
        manager.hide()
        manager.restore()
        #expect(finder.values["CreateDesktop"] as? Bool == false)
    }

    @Test func hidingTwiceKeepsTheFirstSetting() {
        let finder = FakeFinder()
        let manager = FinderManager(finder: finder, memory: freshDefaults(), restartFinder: {})
        manager.hide()
        // Something turned Finder's desktop back on meanwhile: hidden again, the first setting kept.
        finder.values["CreateDesktop"] = true
        manager.hide()
        manager.restore()
        #expect(finder.values["CreateDesktop"] == nil)
    }

    @Test func hidingWhatIsAlreadyHiddenDoesntRestartFinder() {
        let finder = FakeFinder()
        var restarts = 0
        let manager = FinderManager(finder: finder, memory: freshDefaults(), restartFinder: { restarts += 1 })
        manager.hide()
        manager.hide()
        #expect(restarts == 1)
    }

    @Test func restoringWithoutHidingChangesNothing() {
        let finder = FakeFinder(["CreateDesktop": false])
        var restarts = 0
        let manager = FinderManager(finder: finder, memory: freshDefaults(), restartFinder: { restarts += 1 })
        manager.restore()
        #expect(finder.values["CreateDesktop"] as? Bool == false)
        #expect(restarts == 0)
    }
}
