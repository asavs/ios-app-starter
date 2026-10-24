//
//  ContentView.swift
//  StarterApp
//
//

import SwiftUI
// Modules are optional per project.yml; reference them only under canImport.
#if canImport(TemplateVersion)
import TemplateVersion
#endif
#if canImport(Theme)
import Theme
#endif
#if canImport(Onboarding)
import Onboarding
#endif
#if canImport(Settings)
import Settings
#endif

struct ContentView: View {
#if canImport(Settings)
    @State private var isShowingSettings = false
#endif
#if canImport(Settings) && canImport(Onboarding)
    @State private var tourResetPending = false
    @State private var tipsResetPending = false
#endif
#if canImport(Onboarding)
    @State private var isReplayingTour = false
    /// The onboarding choice step's answer: option identifiers, comma separated.
    @AppStorage(ContentView.buildGoalsKey) private var buildGoals = ""
    /// Contextual tips in the order they show: one at a time, each next to its control, after onboarding.
    @State private var tips = ContextualTipSequence(ContentView.tips)
#endif

    var body: some View {
#if canImport(Settings)
        NavigationStack {
            welcome
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
#if canImport(Onboarding)
                            tips.invalidate("settings")
#endif
                            isShowingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityIdentifier("settings.open")
                    }
                }
                .navigationDestination(isPresented: $isShowingSettings) {
                    settings
                }
        }
#else
        welcome
#endif
    }

    /// Centred when it fits; scrolls instead of overflowing when Dynamic Type needs the room.
    private var welcome: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
#if canImport(Onboarding) && canImport(Settings)
                    // Inline, because a popover anchored to a toolbar button does not appear on iOS 26.
                    ContextualTipView("settings", in: tips)
#endif
                    Image(systemName: "globe")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true) // Decorative.
                    Text("Hello, world!")
                        .accessibilityAddTraits(.isHeader)
                    details
                    replayTour
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// Replays the onboarding flow in a sheet; the theme's prominent style, as on onboarding's Continue.
    /// Onboarding depends on Theme, so the style is available whenever the button is.
    @ViewBuilder private var replayTour: some View {
#if canImport(Onboarding)
        Button {
            tips.invalidate("tour") // Done what the tip suggests: retire it.
            isReplayingTour = true
        } label: {
            Text("Take the tour")
                .frame(maxWidth: .infinity)
        }
        .prominentButtonStyle()
        .accessibilityIdentifier("onboarding.replay")
        .contextualTip("tour", in: tips, arrowEdge: .bottom)
        .sheet(isPresented: $isReplayingTour) {
            OnboardingView(steps: OnboardingStep.template(onChoice: ContentView.rememberBuildGoals)) {
                isReplayingTour = false
            }
        }
#endif
    }

#if canImport(Onboarding)
    static let buildGoalsKey = "starter.buildGoals"

    /// Stores the choice step's answer where the welcome screen reads it; an app would adapt its content instead.
    /// The identifiers are stored, never the titles, so the answer survives a change of language.
    static func rememberBuildGoals(_ goals: [String]) {
        UserDefaults.standard.set(goals.joined(separator: ","), forKey: buildGoalsKey)
    }

    /// The stored answer as the picked options' titles in the current language, as a list ("A and B").
    private var buildGoalTitles: String {
        OnboardingStep.templateChoice()
            .titles(for: buildGoals.split(separator: ",").map(String.init))
            .map { String(localized: $0) }
            .formatted(.list(type: .and))
    }

    /// The template's tips. The Settings tip comes first when that module is enabled.
    private static var tips: [ContextualTip] {
        var tips: [ContextualTip] = []
#if canImport(Settings)
        tips.append(ContextualTip(id: "settings", title: "Settings live here",
                                  message: "Tap the gear to pick light or dark, store secrets and show the tour again.",
                                  systemImage: "gearshape"))
#endif
        tips.append(ContextualTip(id: "tour", title: "See the tour again",
                                  message: "Replay onboarding any time without resetting it.",
                                  systemImage: "sparkles"))
        return tips
    }
#endif

#if canImport(Settings)
    /// The Settings module's screen with the app's own rows. Replace the example secret with real ones.
    private var settings: some View {
        SettingsView {
            Section("Example secret") {
                SecureSettingRow("API key", key: "example.apiKey")
            }
#if canImport(Onboarding)
            Section("Welcome tour") {
                resetButton("Show the welcome tour on next launch", done: "The welcome tour shows on next launch",
                            isDone: $tourResetPending) {
                    OnboardingRecord().reset()
                }
                .accessibilityIdentifier("settings.onboarding.reset")
                resetButton("Show tips again on next launch", done: "Tips show again on next launch",
                            isDone: $tipsResetPending) {
                    ContextualTips.resetOnNextLaunch()
                }
                .accessibilityIdentifier("settings.tips.reset")
            }
#endif
        }
    }
#endif

#if canImport(Settings) && canImport(Onboarding)
    /// A button whose effect only shows after a relaunch: once tapped it says so and turns inactive.
    private func resetButton(_ title: LocalizedStringResource, done: LocalizedStringResource, isDone: Binding<Bool>,
                             action: @escaping () -> Void) -> some View {
        Button {
            action()
            isDone.wrappedValue = true
            AccessibilityNotification.Announcement(String(localized: done)).post()
        } label: {
            if isDone.wrappedValue {
                Label { Text(done) } icon: { Image(systemName: "checkmark") }
            } else {
                Text(title)
            }
        }
        .disabled(isDone.wrappedValue)
    }
#endif

    /// Build details under the greeting: on a themed card when the Theme module is enabled, plain otherwise.
    @ViewBuilder private var details: some View {
#if canImport(Theme)
        ThemedCard { detailLines }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("welcome.card")
#else
        detailLines
#endif
    }

    @ViewBuilder private var detailLines: some View {
        VStack(spacing: 4) {
            Text("Built on GitHub Actions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#if canImport(TemplateVersion)
            Text("Modules \(TemplateVersion.modules)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("welcome.modulesVersion")
#endif
#if canImport(Onboarding)
            if !buildGoalTitles.isEmpty {
                Text("Building: \(buildGoalTitles)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("welcome.buildGoals")
            }
#endif
        }
        .multilineTextAlignment(.center) // Wrapped lines stay centred at large text sizes.
    }
}

#Preview {
    ContentView()
}
