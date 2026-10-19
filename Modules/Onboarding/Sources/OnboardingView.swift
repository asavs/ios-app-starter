import SwiftUI
import Theme

/// A swipeable page sequence with Skip, Continue and a final call to action.
///
/// `onFinish` runs once, whether the user reached the last page or skipped. Accessibility
/// identifiers for UI tests: `onboarding.skip`, `onboarding.next`, `onboarding.page.<id>`.
public struct OnboardingView: View {
    @Environment(\.appTheme) private var theme
    private let pages: [OnboardingPage]
    private let skipTitle: String
    private let continueTitle: String
    private let finishTitle: String
    private let onFinish: @MainActor () -> Void
    @State private var pager: OnboardingPager

    /// - Parameters:
    ///   - pages: The screens, in order. An empty array finishes immediately on appear.
    ///   - skipTitle: Label of the top trailing button; `nil` removes it so every page must be seen.
    ///   - continueTitle: Label of the bottom button before the last page.
    ///   - finishTitle: Label of the bottom button on the last page.
    public init(pages: [OnboardingPage], skipTitle: String? = "Skip", continueTitle: String = "Continue",
                finishTitle: String = "Get started", onFinish: @escaping @MainActor () -> Void) {
        self.pages = pages
        self.skipTitle = skipTitle ?? ""
        self.continueTitle = continueTitle
        self.finishTitle = finishTitle
        self.onFinish = onFinish
        _pager = State(initialValue: OnboardingPager(pageCount: pages.count))
    }

    public var body: some View {
        VStack(spacing: theme.spacing.medium) {
            HStack {
                Spacer()
                if !skipTitle.isEmpty {
                    Button(skipTitle, action: onFinish)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                        .accessibilityIdentifier("onboarding.skip")
                        .opacity(pager.isLast ? 0 : 1)
                        .disabled(pager.isLast)
                }
            }
            .padding(.horizontal, theme.spacing.medium)
            pagesView
            Button(pager.isLast ? finishTitle : continueTitle) {
                if pager.advance() {
                    onFinish()
                }
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("onboarding.next")
            .padding(.horizontal, theme.spacing.medium)
        }
        .padding(.vertical, theme.spacing.medium)
        .background(theme.colors.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: pager)
        .onAppear {
            if pages.isEmpty { onFinish() }
        }
    }

    private var selection: Binding<Int> {
        Binding(get: { pager.index }, set: { pager.select($0) })
    }

    @ViewBuilder private var pagesView: some View {
#if os(iOS)
        // The page style and its dots exist on iOS only; the package also compiles for macOS so
        // `swift test` can run host-side, where a plain page switch is enough.
        TabView(selection: selection) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { offset, page in
                OnboardingPageView(page).tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
#else
        if pages.indices.contains(pager.index) {
            OnboardingPageView(pages[pager.index])
        }
#endif
    }
}

#Preview("Onboarding") {
    OnboardingView(pages: OnboardingPage.templateDefaults) {}
}
