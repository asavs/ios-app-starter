import SwiftUI
#if canImport(Settings)
import Settings
#if canImport(Onboarding)
import Onboarding
#endif
#if canImport(Cues)
import Cues
#endif

/// The same host-owned Settings content is used in a tab or, without TabShell, behind the gear.
///
/// A short grouped index, the way iOS Settings is laid out: the app's own controls first (Appearance
/// stays inline as the most-touched one; a module's settings are a row that pushes its screen),
/// then the template's examples, then data, then About. Each module offers its settings as a
/// section and as a row; the app picks (docs/modules.md, "Settings from other modules").
struct StarterSettingsView: View {
#if canImport(Onboarding)
    @State private var tourResetPending = false
    @State private var tipsResetPending = false
#endif

    var body: some View {
        SettingsView {
#if canImport(Cues)
            Section {
                CueSettingsLink()
            }
#endif
            Section {
                SecureSettingRow("API key", key: "example.apiKey")
#if canImport(Onboarding)
                NextLaunchResetButton("Show the welcome tour on next launch", done: "The welcome tour shows on next launch",
                                      isDone: $tourResetPending) {
                    OnboardingRecord().reset()
                }
                .accessibilityIdentifier("settings.onboarding.reset")
                NextLaunchResetButton("Show tips again on next launch", done: "Tips show again on next launch",
                                      isDone: $tipsResetPending) {
                    ContextualTips.resetOnNextLaunch()
                }
                .accessibilityIdentifier("settings.tips.reset")
#endif
            } header: {
                Text("Examples")
            } footer: {
                Text("Rows a real app replaces: a secret kept in the Keychain, and the welcome tour's reset.")
            }
            Section {
                PrivacyNoticeLink(.starter)
                ResetLocalDataButton(reset: StarterLocalData.reset)
            } header: {
                Text("Your data")
            } footer: {
                Text("Erasing removes your settings, the example API key and the welcome tour record from this device. The app stays installed.")
            }
        } about: {
            AcknowledgementsLink(Acknowledgement.starter)
        }
    }
}
#endif
