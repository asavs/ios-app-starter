import SwiftUI

/// Centered symbol, title and message for a screen with nothing to show yet, with an optional action.
public struct EmptyStateView: View {
    @Environment(\.appTheme) private var theme
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (@MainActor () -> Void)?

    /// - Parameters:
    ///   - systemImage: SF Symbol name.
    ///   - actionTitle: Label of the primary button; omit both action parameters for no button.
    public init(systemImage: String, title: String, message: String,
                actionTitle: String? = nil, action: (@MainActor () -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: theme.spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(theme.colors.accent)
                .accessibilityHidden(true)
            VStack(spacing: theme.spacing.extraSmall) {
                Text(title)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
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
