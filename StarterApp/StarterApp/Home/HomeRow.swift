import SwiftUI
#if canImport(TabShell)
import Theme

/// A row on one of Home's cards: a symbol, a title, a line under it and a chevron, read by
/// VoiceOver as one element. Wrap it in a Button; the row draws no button chrome of its own.
struct HomeRow: View {
    let systemImage: String
    let title: Text
    let detail: Text
    @ScaledMetric(relativeTo: .body) private var symbolWidth: CGFloat = 28
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.medium) {
            Image(systemName: systemImage)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.accent)
                .frame(width: symbolWidth)
                .accessibilityHidden(true) // The title says what it is.
            VStack(alignment: .leading, spacing: theme.spacing.extraSmall) {
                title
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)
                detail
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, theme.spacing.small)
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
#endif
