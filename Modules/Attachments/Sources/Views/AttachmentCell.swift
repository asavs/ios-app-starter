import SwiftUI
import Theme

/// One attachment in the grid: its thumbnail and name, one accessibility element that says what it
/// is ("Photo, invoice.pdf"), tapped to preview, with Remove as an action and in the context menu.
/// Identifiers: `attachments.item.<id>`, `attachments.item.<id>.remove`.
struct AttachmentCell: View {
    let attachment: Attachment
    let store: any AttachmentStoring
    let caption: String?
    let isWide: Bool
    let onSelect: () -> Void
    let onRemove: (() -> Void)?
    @Environment(\.appTheme) private var theme
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .body) private var thumbnailSize = 96.0

    var body: some View {
        Button(action: onSelect) {
            if isWide {
                HStack(spacing: theme.spacing.medium) {
                    thumbnail(Color.clear.frame(width: thumbnailSize, height: thumbnailSize))
                    text
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: theme.spacing.extraSmall) {
                    thumbnail(Color.clear.aspectRatio(1, contentMode: .fit))
                    text
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label { Text("Remove", bundle: .module) } icon: { Image(systemName: "trash") }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: description))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Remove", bundle: .module)) { onRemove?() }
        .accessibilityIdentifier("attachments.item.\(attachment.id.uuidString)")
    }

    /// The thumbnail drawn over a frame of the cell's choosing and clipped to it, so a filled image
    /// never spills into the next cell.
    private func thumbnail(_ frame: some View) -> some View {
        frame
            .overlay { AttachmentThumbnailView(attachment: attachment, store: store, pixelSize: Int(thumbnailSize * 3 * displayScale)) }
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: caption ?? attachment.displayName)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(isWide ? 3 : 2)
            Text(verbatim: kindName)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .multilineTextAlignment(.leading)
    }

    private var kindName: String {
        switch attachment.kind {
        case .image: String(localized: "Photo", bundle: .module)
        case .movie: String(localized: "Video", bundle: .module)
        case .file: attachment.type?.localizedDescription ?? String(localized: "File", bundle: .module)
        case .link: attachment.url?.host() ?? String(localized: "Link", bundle: .module)
        }
    }

    /// "Photo, invoice.pdf": the kind, then the caption or name.
    private var description: String {
        "\(kindName), \(caption ?? attachment.displayName)"
    }
}
