import SwiftUI
import Theme

/// One feature row of the welcome step: accent symbol, title and detail.
public struct WelcomeFeatureRow: View {
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title2) private var symbolWidth: CGFloat = 36
    private let feature: WelcomeFeature

    public init(_ feature: WelcomeFeature) {
        self.feature = feature
    }

    public var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.medium) {
            Image(systemName: feature.systemImage)
                .font(.title2)
                .foregroundStyle(theme.colors.accent)
                .frame(minWidth: symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: theme.spacing.extraSmall) {
                Text(feature.title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(feature.detail)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.feature.\(feature.id)")
    }
}

#Preview("Feature row") {
    WelcomeFeatureRow(WelcomeFeature(id: "notify", systemImage: "bell", title: "Stay informed", detail: "Why notifications help."))
        .padding()
}
