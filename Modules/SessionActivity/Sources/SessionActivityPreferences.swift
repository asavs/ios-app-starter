import Foundation

/// Whether the app shows a session as a Live Activity, stored in `UserDefaults` under
/// `sessionActivity.enabled`. On by default: the HIG asks that an activity follow a person's own
/// action (starting the session) and that the app offer a way to turn it off, which
/// `SessionActivitySettingsSection` is.
public struct SessionActivityPreferences: Sendable, Equatable {
    public static let enabledKey = "sessionActivity.enabled"
    public static let defaultEnabled = true

    public var isEnabled: Bool

    public init(isEnabled: Bool = defaultEnabled) {
        self.isEnabled = isEnabled
    }

    /// The stored value, or the default for a key never written.
    public init(defaults: UserDefaults) {
        self.init(isEnabled: defaults.object(forKey: Self.enabledKey) as? Bool ?? Self.defaultEnabled)
    }
}
