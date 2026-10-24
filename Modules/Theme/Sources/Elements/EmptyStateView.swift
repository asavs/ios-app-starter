import SwiftUI

/// Centered symbol, title and message for a screen with nothing to show yet, with an optional action.
public struct EmptyStateView: View {
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .title) private var symbolSize: CGFloat = 44
    private let systemImage: String
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource
    private let actionTitle: LocalizedStringResource?
    private let action: (@MainActor () -> Void)?

    /// - Parameters:
    ///   - systemImage: SF Symbol name.
    ///   - title: Looked up in the app's string catalog when written as a literal, like every text
    ///     parameter in the modules.
    ///   - actionTitle: Label of the primary button; omit both action parameters for no button.
    public init(systemImage: String, title: LocalizedStringResource, message: LocalizedStringResource,
                actionTitle: LocalizedStringResource? = nil, action: (@MainActor () -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: theme.spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize))
                .foregroundStyle(theme.colors.accent)
                .accessibilityHidden(true)
            VStack(spacing: theme.spacing.extraSmall) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .frame(maxWidth: .infinity)
                }
                .prominentButtonStyle()
                .padding(.top, theme.spacing.small)
            }
        }
        .padding(theme.spacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty state") {
    EmptyStateView(systemImage: "tray", title: "No notes yet",
                   message: "Notes you create appear here.", actionTitle: "New note") {}
}
