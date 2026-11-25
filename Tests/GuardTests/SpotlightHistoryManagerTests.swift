import Foundation
import Testing
@testable import SpotlightGuard

private func freshDefaults() -> UserDefaults {
    let name = "SpotlightHistoryManagerTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

/// Spotlight's preferences domain in memory: the real Spotlight is never touched by tests.
private final class FakeSpotlight: PreferenceDomain {
    var values: [String: Any]
    init(_ values: [String: Any] = [:]) { self.values = values }
    func value(forKey key: String) -> Any? { values[key] }
    func setValue(_ value: Any?, forKey key: String) { values[key] = value }
}

@Suite struct SpotlightHistoryManagerTests {
    @Test func turningOffKeepsSpotlightsSetting() {
        let spotlight = FakeSpotlight()
        let manager = SpotlightHistoryManager(spotlight: spotlight, memory: freshDefaults())
        manager.turnOff()
        #expect(spotlight.values["PasteboardHistoryEnabled"] as? Bool == false)
        #expect(manager.isHiding)
    }

    @Test func restoringPutsBackSpotlightsDefault() {
        let spotlight = FakeSpotlight()
        let manager = SpotlightHistoryManager(spotlight: spotlight, memory: freshDefaults())
        manager.turnOff()
        manager.restore()
        #expect(spotlight.values["PasteboardHistoryEnabled"] == nil)
        #expect(!manager.isHiding)
    }

    @Test func aHistoryTheUserTurnedOnOrOffComesBackSo() {
        for before in [true, false] {
            let spotlight = FakeSpotlight(["PasteboardHistoryEnabled": before])
            let manager = SpotlightHistoryManager(spotlight: spotlight, memory: freshDefaults())
            manager.turnOff()
            manager.restore()
            #expect(spotlight.values["PasteboardHistoryEnabled"] as? Bool == before)
        }
    }

    @Test func turningOffTwiceKeepsTheFirstSetting() {
        let spotlight = FakeSpotlight(["PasteboardHistoryEnabled": true])
        let manager = SpotlightHistoryManager(spotlight: spotlight, memory: freshDefaults())
        manager.turnOff()
        manager.turnOff()
        manager.restore()
        #expect(spotlight.values["PasteboardHistoryEnabled"] as? Bool == true)
    }

    /// The setting Clipboard kept before it used this library ("on", "off", "none") still restores.
    @Test func readsWhatClipboardKeptBefore() {
        let memory = freshDefaults()
        memory.set("on", forKey: "SpotlightHistoryBefore")
        let spotlight = FakeSpotlight(["PasteboardHistoryEnabled": false])
        let manager = SpotlightHistoryManager(spotlight: spotlight, memory: memory)
        #expect(manager.isHiding)
        manager.restore()
        #expect(spotlight.values["PasteboardHistoryEnabled"] as? Bool == true)
    }

    @Test func restoringWithNothingKeptChangesNothing() {
        let spotlight = FakeSpotlight(["PasteboardHistoryEnabled": false])
        let manager = SpotlightHistoryManager(spotlight: spotlight, memory: freshDefaults())
        manager.restore()
        #expect(spotlight.values["PasteboardHistoryEnabled"] as? Bool == false)
    }
}
