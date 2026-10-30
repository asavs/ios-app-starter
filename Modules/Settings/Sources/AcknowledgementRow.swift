import SwiftUI
import Theme

/// One acknowledgement: name, author and licence, as a link when there is a URL. VoiceOver reads
/// the row as one element.
struct AcknowledgementRow: View {
    let entry: Acknowledgement
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let url = entry.url {
            Link(destination: url) { details }
        } else {
            details
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: theme.spacing.extraSmall) {
            Text(verbatim: entry.name)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            if let author = entry.author {
                Text(verbatim: author)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            if let license = entry.license {
                Text(license)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
