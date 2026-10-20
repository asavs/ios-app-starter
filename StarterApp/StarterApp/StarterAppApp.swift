//
//  StarterAppApp.swift
//  StarterApp
//
//

import SwiftUI
// Modules are optional per project.yml; reference them only under canImport.
#if canImport(Onboarding)
import Onboarding
#endif
#if canImport(Settings)
import Settings
#endif

@main
struct StarterAppApp: App {
    var body: some Scene {
        WindowGroup {
            root
                .modifier(Appearance())
        }
    }

    /// The welcome screen, behind the onboarding flow on first launch when the Onboarding module is enabled.
    /// Replace `templateDefaults` with the app's own steps; raise `version` to show a revised flow again
    /// (version 2 replaced the three tour cards with a welcome sheet, one card and a notifications primer).
    @ViewBuilder private var root: some View {
#if canImport(Onboarding)
        ContentView()
            .onboardingGate(steps: OnboardingStep.templateDefaults, version: 2)
#else
        ContentView()
#endif
    }
}

/// Applies the appearance chosen in Settings (light, dark or system) when the Settings module is enabled.
private struct Appearance: ViewModifier {
    func body(content: Content) -> some View {
#if canImport(Settings)
        content.storedAppearance()
#else
        content
#endif
    }
}
