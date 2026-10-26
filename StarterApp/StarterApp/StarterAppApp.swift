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
#if canImport(Onboarding)
    init() {
        ContextualTips.configure() // Before any tip view appears.
    }
#endif

    var body: some Scene {
        WindowGroup {
            root
                .modifier(Appearance())
        }
    }

    /// The welcome screen, behind the onboarding flow on first launch when the Onboarding module is enabled.
    /// Replace the template steps with the app's own; raise `version` to show a revised flow again
    /// (version 2 replaced the three tour cards with a welcome sheet, one card and a notifications primer;
    /// version 3 added the choice step, whose answer the welcome screen shows).
    @ViewBuilder private var root: some View {
#if canImport(Onboarding)
        appContent
            .onboardingGate(steps: OnboardingStep.template(onChoice: ContentView.rememberBuildGoals), version: 3)
#else
        appContent
#endif
    }

    @ViewBuilder private var appContent: some View {
#if canImport(TabShell)
        StarterTabsView()
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
