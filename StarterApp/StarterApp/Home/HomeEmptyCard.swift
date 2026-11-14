import SwiftUI
#if canImport(TabShell)
import Theme

/// What a Home section says before its feature holds anything, and the action that adds the first
/// thing. The message is identified as `identifier`, the button as `actionIdentifier`.
struct HomeEmptyCard: View {
    let message: LocalizedStringResource
    let actionTitle: LocalizedStringResource
    let systemImage: String
    let identifier: String
    let actionIdentifier: String
    let action: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.medium) {
            Text(message)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
            Button(action: action) {
                Label { Text(actionTitle) } icon: { Image(systemName: systemImage) }
            }
            .buttonStyle(.bordered)
            .controlSize(.large) // A 44-point target.
            .accessibilityIdentifier(actionIdentifier)
        }
        .padding(.vertical, theme.spacing.small)
    }
}
#endif
