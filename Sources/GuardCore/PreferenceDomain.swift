import Foundation

/// A preferences domain, such as `com.apple.dock` or `com.apple.finder`. Tests use a dictionary instead
/// of the real Dock or Finder.
public protocol PreferenceDomain: AnyObject {
    func value(forKey key: String) -> Any?
    /// `nil` removes the key.
    func setValue(_ value: Any?, forKey key: String)
}

/// Another app's preferences, through the public CFPreferences calls `defaults` uses.
public final class AppPreferenceDomain: PreferenceDomain {
    public let identifier: String

    public init(_ identifier: String) { self.identifier = identifier }

    public func value(forKey key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, identifier as CFString)
    }

    public func setValue(_ value: Any?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value.map { $0 as AnyObject }, identifier as CFString)
        CFPreferencesAppSynchronize(identifier as CFString)
    }
}
