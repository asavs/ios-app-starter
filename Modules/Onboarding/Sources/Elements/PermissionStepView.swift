import SwiftUI
import Theme

/// The pre-permission step: the primer as a tour card plus its footnote. The single Continue button
/// belongs to the flow, which runs the primer's requester when it is tapped.
public struct PermissionStepView: View {
    @Environment(\.appTheme) private var theme
    private let primer: PermissionPrimer

    public init(_ primer: PermissionPrimer) {
        self.primer = primer
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.medium) {
                OnboardingPageView(primer.page)
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.8 }
                if let footnote = primer.footnote {
                    Text(footnote)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, theme.spacing.extraLarge)
                        .accessibilityIdentifier("onboarding.permission.\(primer.id).footnote")
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview("Permission") {
    PermissionStepView(PermissionPrimer(id: "notifications", systemImage: "bell.badge", title: "Stay in the loop",
                                        message: "Why notifications help.", requester: FakePermission()))
}
