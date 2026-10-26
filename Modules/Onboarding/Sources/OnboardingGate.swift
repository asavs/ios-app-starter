import SwiftUI

/// Shows the onboarding flow in a sheet over its content until the user finishes it once.
///
/// ```swift
/// ContentView().onboardingGate(steps: OnboardingStep.templateDefaults)
/// ```
///
/// Completion is remembered through `OnboardingRecord`; raise `version` to show a revised flow
/// to users who completed an earlier one. Within a launch the decision is kept in view state, so
/// finishing releases the gate even when a launch argument pins the stored value. Contextual tips
/// stay ineligible while the flow is on screen (`ContextualTips.isEligible`).
///
/// It is the same sheet a replay uses. Swiping it down, or VoiceOver's escape gesture, counts as
/// Skip: onboarding is optional, and a dismissed flow is not shown again.
public extension View {
    func onboardingGate(steps: [OnboardingStep], version: Int = 1,
                        record: OnboardingRecord = OnboardingRecord()) -> some View {
        modifier(OnboardingGate(steps: steps, version: version, record: record))
    }

    /// Tour cards only; the same as `onboardingGate(steps: OnboardingStep.pages(pages))`.
    func onboardingGate(pages: [OnboardingPage], version: Int = 1,
                        record: OnboardingRecord = OnboardingRecord()) -> some View {
        onboardingGate(steps: OnboardingStep.pages(pages), version: version, record: record)
    }
}

struct OnboardingGate: ViewModifier {
    let steps: [OnboardingStep]
    let version: Int
    let record: OnboardingRecord
    @State private var isComplete: Bool
    @State private var isPresented: Bool

    init(steps: [OnboardingStep], version: Int, record: OnboardingRecord) {
        self.steps = steps
        self.version = version
        self.record = record
        let complete = steps.isEmpty || record.isComplete(version: version)
        _isComplete = State(initialValue: complete)
        _isPresented = State(initialValue: !complete)
    }

    func body(content: Content) -> some View {
        content
            // The system sheet animates itself and follows Reduce Motion.
            .sheet(isPresented: $isPresented, onDismiss: complete) {
                OnboardingView(steps: steps) {
                    isPresented = false
                }
            }
            .onAppear {
                ContextualTips.isEligible = isComplete
            }
    }

    /// Runs once the sheet is gone, however it was closed.
    private func complete() {
        guard !isComplete else { return }
        record.markComplete(version: version)
        isComplete = true
        ContextualTips.isEligible = true
    }
}
