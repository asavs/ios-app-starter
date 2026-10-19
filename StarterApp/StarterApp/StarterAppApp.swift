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

@main
struct StarterAppApp: App {
    var body: some Scene {
        WindowGroup {
            root
        }
    }

    /// The welcome screen, behind the onboarding flow on first launch when the Onboarding module is enabled.
    /// Replace `templateDefaults` with the app's own pages; raise `version` to show a revised flow again.
    @ViewBuilder private var root: some View {
#if canImport(Onboarding)
        ContentView()
            .onboardingGate(pages: OnboardingPage.templateDefaults, version: 1)
#else
        ContentView()
#endif
    }
}
