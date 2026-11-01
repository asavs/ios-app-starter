import SwiftUI
import Theme

/// Thumbnails in an adaptive grid, or one column with the name beside the thumbnail at the
/// accessibility text sizes, the way Photos and Files lay out. Tapping selects for a preview
/// (pair it with `attachmentPreview(_:in:store:)`); Remove is the cell's action.
public struct AttachmentGrid: View {
    private let attachments: [Attachment]
    private let store: any AttachmentStoring
    private let caption: (Attachment) -> String?
    private let onRemove: ((Attachment) -> Void)?
    @Binding private var selection: Attachment?
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var cellMinimum = 100.0

    /// - Parameters:
    ///   - caption: Text under a thumbnail instead of the display name, such as an app's caption.
    ///   - onRemove: Offered as a context menu entry and an accessibility action; nil hides it.
    public init(_ attachments: [Attachment], store: any AttachmentStoring, selection: Binding<Attachment?>,
                caption: @escaping (Attachment) -> String? = { _ in nil }, onRemove: ((Attachment) -> Void)? = nil) {
        self.attachments = attachments
        self.store = store
        _selection = selection
        self.caption = caption
        self.onRemove = onRemove
    }

    public var body: some View {
        let wide = dynamicTypeSize.isAccessibilitySize
        LazyVGrid(columns: [GridItem(wide ? .flexible() : .adaptive(minimum: cellMinimum), spacing: theme.spacing.medium)],
                  alignment: .leading, spacing: theme.spacing.medium) {
            ForEach(attachments) { attachment in
                AttachmentCell(attachment: attachment, store: store, caption: caption(attachment), isWide: wide,
                               onSelect: { selection = attachment },
                               onRemove: onRemove.map { remove in { remove(attachment) } })
            }
        }
        .accessibilityIdentifier("attachments.grid")
    }
}
