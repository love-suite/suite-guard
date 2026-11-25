import Foundation
import IOKit
@_exported import GuardCore

/// When lid sleep comes back: Awake, which turns it off for a closed-lid session, gone.
public typealias ClamshellGuardRule = GuardRule

/// Turning the Mac's sleep on closing the lid off and back on. Tests use a fake instead of the real Mac.
public protocol ClamshellSleepSwitch: AnyObject {
    /// True: closing the lid doesn't sleep the Mac. False: macOS' own behaviour. Returns whether it took.
    @discardableResult
    func setSleepDisabled(_ disabled: Bool) -> Bool
}

/// The Mac's own switch: `IOPMrootDomain`'s user client, selector `kPMSetClamshellSleepState` (12).
///
/// The selector is defined in the public SDK header `IOKit/pwr_mgt/IOPMLibDefs.h`, but what it does is not
/// documented: xnu (`RootDomainUserClient.cpp`) calls `setClamShellSleepDisable(value,
/// kClamshellSleepDisablePowerd)`, with no entitlement and no root needed. The setting outlives the process
/// that set it (until it is set back, powerd resets it, or the Mac restarts): that is why Suite Guard puts it
/// back should Awake vanish. Apple may change this in any release.
public final class RootDomainClamshellSwitch: ClamshellSleepSwitch {
    public init() {}

    /// `kPMSetClamshellSleepState`, from IOPMLibDefs.h (a macro Swift doesn't import).
    static let selector: UInt32 = 12

    @discardableResult
    public func setSleepDisabled(_ disabled: Bool) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return false }
        defer { IOServiceClose(connection) }
        var input: UInt64 = disabled ? 1 : 0
        return IOConnectCallScalarMethod(connection, Self.selector, &input, 1, nil, nil) == KERN_SUCCESS
    }

    /// Whether this Mac has a lid (`AppleClamshellState` on `IOPMrootDomain`, public in IOPM.h).
    public static var hasLid: Bool { rootDomainProperty("AppleClamshellState") != nil }

    /// Whether the lid is closed now.
    public static var isLidClosed: Bool { (rootDomainProperty("AppleClamshellState") as? Bool) ?? false }

    /// Whether closing the lid sleeps the Mac now (`AppleClamshellCausesSleep`): reads the switch back.
    public static var lidClosingSleeps: Bool { (rootDomainProperty("AppleClamshellCausesSleep") as? Bool) ?? true }

    private static func rootDomainProperty(_ key: String) -> Any? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

/// Lid sleep, which Awake turns off during a closed-lid session. Before turning it off it notes so in
/// Awake's preferences (`savedKey`), so that Suite Guard, should Awake vanish, turns it back on: a Mac must
/// never be left awake in a bag.
public final class ClamshellSleepManager {
    /// The key, in Awake's preferences, set while lid sleep is off because of Awake.
    public static let savedKey = "ClamshellSleepDisabledByAwake"

    private let control: ClamshellSleepSwitch
    private let memory: UserDefaults

    public init(control: ClamshellSleepSwitch = RootDomainClamshellSwitch(), memory: UserDefaults = .standard) {
        self.control = control
        self.memory = memory
    }

    /// True while lid sleep is off because of us.
    public var isHiding: Bool { memory.bool(forKey: Self.savedKey) }

    /// Turns lid sleep off (again: powerd turns it back on when the power source changes). Noted first, so a
    /// crash right after still gets it back. Returns whether macOS took it.
    @discardableResult
    public func turnOff() -> Bool {
        memory.set(true, forKey: Self.savedKey)
        memory.synchronize()
        return control.setSleepDisabled(true)
    }

    /// Lid sleep as macOS has it, when we turned it off.
    public func restore() {
        guard isHiding else { return }
        control.setSleepDisabled(false)
        memory.removeObject(forKey: Self.savedKey)
        memory.synchronize()
    }
}
