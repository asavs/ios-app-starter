#if canImport(Onboarding)
import Onboarding

/// The app's onboarding flow, for the first-launch gate and the tour's replay alike: the template's
/// steps, with Choose your tabs after the choice step when the app has tabs. Replace the steps with
/// the app's own.
enum StarterOnboarding {
    /// Raise it to show a revised flow again to people who finished an earlier one. Version 2
    /// replaced the three tour cards with a welcome sheet, one card and a notifications primer;
    /// version 3 added the choice step, whose answer the welcome screen shows. The tab step didn't
    /// raise it: choosing tabs is optional and Settings has the same chooser, so nobody who has
    /// finished onboarding is sent through it again for that step.
    static let version = 3

    static var steps: [OnboardingStep] {
        var steps = OnboardingStep.template(onChoice: ContentView.rememberBuildGoals)
#if canImport(TabShell)
        let afterChoice = steps.firstIndex { $0.id == OnboardingStep.templateChoice().id }.map { $0 + 1 } ?? steps.count
        steps.insert(.custom(id: Identifiers.TabChoices.onboardingStep) { TabChoicesStep() }, at: afterChoice)
#endif
        return steps
    }
}
#endif
