import Foundation
import TipKit

/// Setup, eligibility and reset for contextual tips, in one place.
///
/// Call `configure()` once at launch, before any tip view appears (an `App` initializer). Tips
/// follow Apple's guidance: show one at a time, near the control they describe, after onboarding.
/// UI tests drive the datastore through launch arguments, which `UserDefaults` reads ahead of
/// stored values: `-tips.reset YES` forgets every tip's display history before configuring, and
/// `-tips.testing showAll` (or `hideAll`) ignores the rules so a test sees every tip, or none.
public enum ContextualTips {
    /// The `UserDefaults` key that asks for a datastore reset at the next `configure()`: `tips.reset`.
    public static let resetKey = "tips.reset"
    /// The `UserDefaults` key for test overrides, `showAll` or `hideAll`: `tips.testing`.
    public static let testingKey = "tips.testing"

    /// Configures TipKit, first applying a requested reset and any test override.
    ///
    /// TipKit can only reset its datastore before it is configured, so a reset requested from a
    /// settings screen waits for the next launch. A second call in one process is ignored.
    /// Returns whether this call forgot the tips' history, so the host can tell this launch asked to see
    /// them again; for example, a tab restored from before the reset is not a visit a tip should count.
    @discardableResult
    public static func configure(displayFrequency: Tips.ConfigurationOption.DisplayFrequency = .immediate,
                                 defaults: UserDefaults = .standard) -> Bool {
        let reset = defaults.bool(forKey: resetKey)
        if reset {
            try? Tips.resetDatastore()
            defaults.removeObject(forKey: resetKey)
        }
        switch defaults.string(forKey: testingKey) {
        case "showAll": Tips.showAllTipsForTesting()
        case "hideAll": Tips.hideAllTipsForTesting()
        default: break
        }
        // Throws only when TipKit is already configured, which leaves the first configuration in place.
        try? Tips.configure([.displayFrequency(displayFrequency)])
        return reset
    }

    /// Shows every tip again from the next launch, for a settings screen.
    public static func resetOnNextLaunch(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: resetKey)
    }

    /// Whether contextual tips may show at all. `true` unless something turns it off; the onboarding
    /// gate does while its flow is on screen. Set it from the main actor, like any view state.
    @MainActor public static var isEligible: Bool {
        get { ContextualTip.isEligible }
        set { ContextualTip.isEligible = newValue }
    }
}
