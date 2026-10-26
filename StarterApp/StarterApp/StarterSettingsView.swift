import SwiftUI
#if canImport(Settings)
import Settings
#if canImport(Onboarding)
import Onboarding
#endif

/// The same host-owned Settings content is used in a tab or, without TabShell, behind the gear.
struct StarterSettingsView: View {
#if canImport(Onboarding)
    @State private var tourResetPending = false
    @State private var tipsResetPending = false
#endif

    var body: some View {
        SettingsView {
            Section("Example secret") {
                SecureSettingRow("API key", key: "example.apiKey")
            }
#if canImport(Onboarding)
            Section("Welcome tour") {
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
            }
#endif
        }
    }
}
#endif
