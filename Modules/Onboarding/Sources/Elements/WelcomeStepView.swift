import SwiftUI
import Theme

/// The welcome step laid out in the system convention: icon, large title, optional line, then
/// feature rows aligned to the leading edge. Scrolls when Dynamic Type needs the room.
public struct WelcomeStepView: View {
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var imageSize: CGFloat = 96
    private let content: WelcomeContent

    public init(_ content: WelcomeContent) {
        self.content = content
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.large) {
                icon
                    .accessibilityHidden(true)
                VStack(spacing: theme.spacing.small) {
                    // The welcome sheet convention uses the large title; the theme's title is for screens.
                    Text(content.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(theme.colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let message = content.message {
                        Text(message)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: theme.spacing.medium) {
                    ForEach(content.features) { feature in
                        WelcomeFeatureRow(feature)
                    }
                }
                .padding(.top, theme.spacing.small)
            }
            .padding(.horizontal, theme.spacing.extraLarge)
            .padding(.top, theme.spacing.extraLarge)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicatorsFlash(onAppear: true) // At large text sizes, shows there is more below the page dots.
    }

    @ViewBuilder private var icon: some View {
        switch content.icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: symbolSize))
                .foregroundStyle(theme.colors.accent)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                .clipShape(.rect(cornerRadius: theme.radii.large))
        }
    }
}

#Preview("Welcome") {
    if case .welcome(let content) = OnboardingStep.templateDefaults[0].kind {
        WelcomeStepView(content)
    }
}
