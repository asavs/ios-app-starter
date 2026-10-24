import SwiftUI

/// Shows the onboarding flow in place of its content until the user finishes it once.
///
/// ```swift
/// ContentView().onboardingGate(steps: OnboardingStep.templateDefaults)
/// ```
///
/// Completion is remembered through `OnboardingRecord`; raise `version` to show a revised flow
/// to users who completed an earlier one. Within a launch the decision is kept in view state, so
/// finishing releases the gate even when a launch argument pins the stored value. Contextual tips
/// stay ineligible while the flow is on screen (`ContextualTips.isEligible`).
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isComplete: Bool

    init(steps: [OnboardingStep], version: Int, record: OnboardingRecord) {
        self.steps = steps
        self.version = version
        self.record = record
        _isComplete = State(initialValue: steps.isEmpty || record.isComplete(version: version))
    }

    func body(content: Content) -> some View {
        ZStack {
            if isComplete {
                content
                    .transition(.opacity)
            } else {
                OnboardingView(steps: steps) {
                    record.markComplete(version: version)
                    ContextualTips.isEligible = true
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isComplete = true
                    }
                }
                // Reduce Motion keeps the cross-fade and drops the slide.
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            ContextualTips.isEligible = isComplete
        }
    }
}
