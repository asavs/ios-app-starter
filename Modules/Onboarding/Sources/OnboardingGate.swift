import SwiftUI

/// Shows the onboarding flow in place of its content until the user finishes it once.
///
/// ```swift
/// ContentView().onboardingGate(pages: OnboardingPage.templateDefaults)
/// ```
///
/// Completion is remembered through `OnboardingRecord`; raise `version` to show a revised flow
/// to users who completed an earlier one. Within a launch the decision is kept in view state, so
/// finishing releases the gate even when a launch argument pins the stored value.
public extension View {
    func onboardingGate(pages: [OnboardingPage], version: Int = 1,
                        record: OnboardingRecord = OnboardingRecord()) -> some View {
        modifier(OnboardingGate(pages: pages, version: version, record: record))
    }
}

struct OnboardingGate: ViewModifier {
    let pages: [OnboardingPage]
    let version: Int
    let record: OnboardingRecord
    @State private var isComplete: Bool

    init(pages: [OnboardingPage], version: Int, record: OnboardingRecord) {
        self.pages = pages
        self.version = version
        self.record = record
        _isComplete = State(initialValue: pages.isEmpty || record.isComplete(version: version))
    }

    func body(content: Content) -> some View {
        ZStack {
            if isComplete {
                content
                    .transition(.opacity)
            } else {
                OnboardingView(pages: pages) {
                    record.markComplete(version: version)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isComplete = true
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
