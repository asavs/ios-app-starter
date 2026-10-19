import Foundation

/// Whether the user has finished onboarding, stored in `UserDefaults` as the completed version.
///
/// Apps raise `version` when the flow changes enough to show again; a stored version at or above
/// the requested one counts as complete. Nothing here is secret, so `UserDefaults` is the right
/// store; the Settings module is for values that belong in the Keychain.
///
/// UI tests force the flow with a launch argument, which `UserDefaults` reads ahead of the
/// persisted value: `-onboarding.completedVersion 0` shows it, `-onboarding.completedVersion 1`
/// skips version 1.
// `UserDefaults` is documented as thread-safe but not annotated Sendable; the record holds nothing else.
public struct OnboardingRecord: @unchecked Sendable {
    /// The `UserDefaults` key: `onboarding.completedVersion`.
    public static let defaultKey = "onboarding.completedVersion"

    private let defaults: UserDefaults
    public let key: String

    public init(defaults: UserDefaults = .standard, key: String = OnboardingRecord.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    /// The highest version the user has completed; `0` when none.
    public var completedVersion: Int {
        defaults.integer(forKey: key)
    }

    public func isComplete(version: Int) -> Bool {
        completedVersion >= version
    }

    /// Records completion, never lowering a version completed earlier.
    public func markComplete(version: Int) {
        guard version > completedVersion else { return }
        defaults.set(version, forKey: key)
    }

    /// Forgets completion so the flow shows on the next launch; for a settings screen or tests.
    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
