import Foundation
#if canImport(Settings)
import Settings

extension PrivacyNotice {
    /// What the template stores, all of it on the device. An app rewrites these sentences and adds
    /// its privacy policy URL before submission (docs/human-steps.md).
    static var starter: PrivacyNotice {
        var stored: [LocalizedStringResource] = [
            "Your appearance choice and other settings",
            "The example API key, in this device's Keychain",
            "Whether you've seen the welcome tour",
        ]
#if canImport(SessionTimer)
        stored.append("The timer plans you edit")
#endif
        return PrivacyNotice(
            summary: "Starter App works offline. Everything you enter stays on this device.",
            stored: stored,
            deletion: "Erase Local Data in Settings removes all of it. Deleting the app does too.")
    }
}
#endif
