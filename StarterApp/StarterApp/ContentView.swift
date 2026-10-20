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
#if canImport(Onboarding)
    @State private var isReplayingTour = false
#endif

    var body: some View {
#if canImport(Settings)
        NavigationStack {
            welcome
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            settings
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibilityIdentifier("settings.open")
                    }
                }
        }
#else
        welcome
#endif
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            details
            replayTour
        }
        .padding()
    }

    /// Replays the onboarding flow in a sheet; the theme's primary button style on the welcome screen.
    /// Onboarding depends on Theme, so the style is available whenever the button is.
    @ViewBuilder private var replayTour: some View {
#if canImport(Onboarding)
        Button("Take the tour") {
            isReplayingTour = true
        }
        .buttonStyle(.primary)
        .accessibilityIdentifier("onboarding.replay")
        .sheet(isPresented: $isReplayingTour) {
            OnboardingView(steps: OnboardingStep.templateDefaults) {
                isReplayingTour = false
            }
        }
#endif
    }

#if canImport(Settings)
    /// The Settings module's screen with the app's own rows. Replace the example secret with real ones.
    private var settings: some View {
        SettingsView {
            Section("Example secret") {
                SecureSettingRow("API key", key: "example.apiKey")
            }
#if canImport(Onboarding)
            Section("Welcome tour") {
                Button("Show the welcome tour on next launch") {
                    OnboardingRecord().reset()
                }
                .accessibilityIdentifier("settings.onboarding.reset")
            }
#endif
        }
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
#endif
        }
    }
}

#Preview {
    ContentView()
}
