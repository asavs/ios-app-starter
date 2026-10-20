import SwiftUI
import Theme

/// A swipeable step sequence with Skip, a single Continue button and a final call to action.
///
/// `onFinish` runs once, whether the user reached the end or skipped. On a permission step the
/// button runs the primer's requester first and moves on with any outcome. Accessibility
/// identifiers for UI tests: `onboarding.skip`, `onboarding.next`, `onboarding.step.<id>`, plus
/// `onboarding.page.<id>` on tour cards and `onboarding.feature.<id>` on welcome rows.
public struct OnboardingView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let steps: [OnboardingStep]
    private let skipTitle: String
    private let continueTitle: String
    private let finishTitle: String
    private let onFinish: @MainActor () -> Void
    @State private var pager: OnboardingPager
    @State private var isRequesting = false
    @State private var isFinished = false
    @State private var request: Task<Void, Never>?

    /// - Parameters:
    ///   - steps: The stages, in order. An empty array finishes immediately on appear.
    ///   - skipTitle: Label of the top trailing button; `nil` removes it so every step must be seen.
    ///   - continueTitle: Label of the bottom button before the last step, unless the step sets its own.
    ///   - finishTitle: Label of the bottom button on the last step, unless the step sets its own.
    public init(steps: [OnboardingStep], skipTitle: String? = "Skip", continueTitle: String = "Continue",
                finishTitle: String = "Get started", onFinish: @escaping @MainActor () -> Void) {
        self.steps = steps
        self.skipTitle = skipTitle ?? ""
        self.continueTitle = continueTitle
        self.finishTitle = finishTitle
        self.onFinish = onFinish
        _pager = State(initialValue: OnboardingPager(pageCount: steps.count))
    }

    /// Tour cards only; the same as `steps: OnboardingStep.pages(pages)`.
    public init(pages: [OnboardingPage], skipTitle: String? = "Skip", continueTitle: String = "Continue",
                finishTitle: String = "Get started", onFinish: @escaping @MainActor () -> Void) {
        self.init(steps: OnboardingStep.pages(pages), skipTitle: skipTitle, continueTitle: continueTitle,
                  finishTitle: finishTitle, onFinish: onFinish)
    }

    public var body: some View {
        VStack(spacing: theme.spacing.medium) {
            HStack {
                Spacer()
                if !skipTitle.isEmpty {
                    Button(skipTitle, action: finish)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                        .accessibilityIdentifier("onboarding.skip")
                        .opacity(showsSkip ? 1 : 0)
                        .disabled(!showsSkip || isRequesting)
                        .accessibilityHidden(!showsSkip)
                }
            }
            .padding(.horizontal, theme.spacing.medium)
            stepsView
                .allowsHitTesting(!isRequesting) // No swiping away from a primer mid-request.
            OnboardingContinueButton(title: buttonTitle, isBusy: isRequesting, action: advance)
                .padding(.horizontal, theme.spacing.medium)
        }
        .padding(.vertical, theme.spacing.medium)
        .background(theme.colors.background.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: pager)
        .onAppear {
            if steps.isEmpty { finish() }
        }
        .onDisappear {
            request?.cancel()
        }
    }

    private var current: OnboardingStep? {
        steps.indices.contains(pager.index) ? steps[pager.index] : nil
    }

    private var showsSkip: Bool {
        current?.showsSkip(isLast: pager.isLast) ?? false
    }

    private var buttonTitle: String {
        OnboardingView.buttonTitle(for: current, isLast: pager.isLast,
                                   continueTitle: continueTitle, finishTitle: finishTitle)
    }

    /// The Continue label: the step's own title, else a permission primer's, else continue or finish.
    static func buttonTitle(for step: OnboardingStep?, isLast: Bool,
                            continueTitle: String, finishTitle: String) -> String {
        if let title = step?.continueTitle { return title }
        if case .permission(let primer)? = step?.kind { return primer.continueTitle }
        return isLast ? finishTitle : continueTitle
    }

    @MainActor private func advance() {
        guard let current, case .permission(let primer) = current.kind else {
            moveOn()
            return
        }
        isRequesting = true
        request = Task {
            _ = await primer.requester.request()
            guard !Task.isCancelled else { return }
            isRequesting = false
            moveOn()
        }
    }

    @MainActor private func moveOn() {
        if pager.advance() {
            finish()
        }
    }

    /// Runs `onFinish` once, whichever of Skip, the last Continue or an empty flow gets there first.
    @MainActor private func finish() {
        guard !isFinished else { return }
        isFinished = true
        request?.cancel()
        onFinish()
    }

    private var selection: Binding<Int> {
        Binding(get: { pager.index }, set: { pager.select($0) })
    }

    @ViewBuilder private var stepsView: some View {
#if os(iOS)
        // The page style and its dots exist on iOS only; the package also compiles for macOS so
        // `swift test` can run host-side, where a plain step switch is enough.
        TabView(selection: selection) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                stepView(step)
                    // The page dots overlay the bottom of each page; keep step content above them.
                    .padding(.bottom, theme.spacing.extraLarge + theme.spacing.medium)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: steps.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
#else
        if let current {
            stepView(current)
        }
#endif
    }

    @ViewBuilder private func stepView(_ step: OnboardingStep) -> some View {
        Group {
            switch step.kind {
            case .welcome(let content): WelcomeStepView(content)
            case .page(let page): OnboardingPageView(page)
            case .permission(let primer): PermissionStepView(primer)
            case .custom(let content): content.view()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.step.\(step.id)")
    }
}

#Preview("Onboarding") {
    OnboardingView(steps: OnboardingStep.templateDefaults) {}
}
