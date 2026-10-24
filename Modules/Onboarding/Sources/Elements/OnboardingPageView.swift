import SwiftUI
import Theme

/// One onboarding page laid out with the theme: large accent symbol, title, message. Centred when it
/// fits; scrolls instead of truncating when Dynamic Type needs the room.
public struct OnboardingPageView: View {
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 64
    private let page: OnboardingPage
    private let footnote: Footnote?

    /// A line under the card, such as a permission primer's "You can change this in Settings".
    struct Footnote {
        let text: LocalizedStringResource
        let identifier: String
    }

    public init(_ page: OnboardingPage) {
        self.init(page, footnote: nil)
    }

    init(_ page: OnboardingPage, footnote: Footnote?) {
        self.page = page
        self.footnote = footnote
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: theme.spacing.large) {
                    card
                    if let footnote {
                        Text(footnote.text)
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier(footnote.identifier)
                    }
                }
                .padding(.horizontal, theme.spacing.extraLarge)
                .padding(.vertical, theme.spacing.medium)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var card: some View {
        VStack(spacing: theme.spacing.large) {
            Image(systemName: page.systemImage)
                .font(.system(size: symbolSize))
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader) // The page's title leads the combined element: a heading to jump to.
        .accessibilityIdentifier("onboarding.page.\(page.id)")
    }
}

#Preview("Page") {
    OnboardingPageView(OnboardingPage.templateDefaults[0])
}
