import Foundation

/// Lets a launch argument replace real permission prompts with a `FakePermission`, so UI tests on
/// the simulator never meet a system alert: `-onboarding.permissions granted` (or `denied`,
/// `unavailable`). With no override the real requester is used unchanged.
public enum PermissionOverride {
    /// The `UserDefaults` key: `onboarding.permissions`.
    public static let defaultKey = "onboarding.permissions"

    public static func resolve(real: any PermissionRequesting, defaults: UserDefaults = .standard,
                               key: String = PermissionOverride.defaultKey) -> any PermissionRequesting {
        guard let raw = defaults.string(forKey: key), let outcome = PermissionOutcome(rawValue: raw) else {
            return real
        }
        return FakePermission(outcome: outcome)
    }
}
