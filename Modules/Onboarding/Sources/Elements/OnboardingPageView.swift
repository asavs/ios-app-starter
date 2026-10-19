import SwiftUI
import Theme

/// One onboarding page laid out with the theme: large accent symbol, title, message.
public struct OnboardingPageView: View {
    @Environment(\.appTheme) private var theme
    private let page: OnboardingPage

    public init(_ page: OnboardingPage) {
        self.page = page
    }

    public var body: some View {
        VStack(spacing: theme.spacing.large) {
            Image(systemName: page.systemImage)
                .font(.system(size: 64))
                .foregroundStyle(theme.colors.accent)
                .accessibilityHidden(true)
            VStack(spacing: theme.spacing.small) {
                Text(page.title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(page.message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, theme.spacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.page.\(page.id)")
    }
}

#Preview("Page") {
    OnboardingPageView(OnboardingPage.templateDefaults[0])
}
