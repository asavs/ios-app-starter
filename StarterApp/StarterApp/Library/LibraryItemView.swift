import SwiftUI
#if canImport(Database) && canImport(Attachments)
import Attachments
import SwiftData
import Theme

/// One collected item: its picture or link card, its title (the Library's own field, edited in
/// place and saved as typed), what it is, and the actions: preview or open, share, delete. A file
/// whose original is gone keeps its details and says so instead of offering a preview.
/// Accessibility identifiers: `library.detail.title`, `.preview`, `.share`, `.missing`, `.delete`.
struct LibraryItemView: View {
    @Bindable var item: LibraryItem
    @State private var previewing: Attachment?
    @State private var deleting: LibraryItem?
    /// Set the instant the item is deleted, so no render on the way out reads a deleted model.
    @State private var isGone = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    private var store: AttachmentStore { StarterAttachments.store }

    var body: some View {
        if isGone {
            Color.clear
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            Section {
                picture
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                TextField("Title", text: $item.title)
                    .accessibilityIdentifier(Identifiers.Library.Detail.title)
                LabeledContent("Kind", value: item.kindName)
                if !item.attachment.isLink {
                    LabeledContent("Size", value: item.attachment.byteCount, format: .byteCount(style: .file))
                }
                LabeledContent("Added", value: item.createdAt, format: .dateTime.day().month().year())
                if let url = item.attachment.url {
                    LabeledContent("Address") {
                        Text(verbatim: url.absoluteString)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Section {
                if isMissing {
                    Label("The original file is missing. Its details are kept; preview and sharing need the file.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(theme.colors.warning)
                        .accessibilityIdentifier(Identifiers.Library.Detail.missing)
                } else {
                    Button(action: preview) {
                        Label(item.attachment.isLink ? "Open Link" : "Preview", systemImage: item.attachment.isLink ? "safari" : "eye")
                    }
                    .accessibilityIdentifier(Identifiers.Library.Detail.preview)
                    if let shared = item.attachment.url ?? store.fileURL(for: item.attachment) {
                        ShareLink(item: shared)
                            .accessibilityIdentifier(Identifiers.Library.Detail.share)
                    }
                }
            }
            Section {
                Button("Delete from Library", role: .destructive) { deleting = item }
                    .accessibilityIdentifier(Identifiers.Library.Detail.delete)
                    // On the button, so a dialog shown as a popover (iOS 27) points at it.
                    .libraryDeleteConfirmation(item: $deleting) {
                        isGone = true
                        dismiss()
                    }
            }
        }
        .navigationTitle(Text(verbatim: item.title))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item.title) {
            item.modifiedAt = .now
            try? context.save()
        }
        .attachmentPreview($previewing, in: [item.attachment], store: store)
    }

    @ViewBuilder private var picture: some View {
        if item.attachment.isLink {
            LinkPreview(item.attachment, store: store)
        } else {
            LibraryThumbnail(attachment: item.attachment, store: store)
        }
    }

    /// The original is a stored file that isn't where the store says.
    private var isMissing: Bool {
        guard let url = store.fileURL(for: item.attachment) else { return false }
        return !FileManager.default.fileExists(atPath: url.path())
    }

    private func preview() {
        previewing = item.attachment
    }
}

/// The store's thumbnail at a size for a detail screen, decorative: the title beside it says what it is.
private struct LibraryThumbnail: View {
    let attachment: Attachment
    let store: any AttachmentStoring
    @State private var image: CGImage?
    @Environment(\.appTheme) private var theme
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .title) private var size = 200.0

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: attachment.kind == .movie ? "film" : attachment.kind == .image ? "photo" : "doc")
                    .font(.system(size: size / 3))
                    .foregroundStyle(theme.colors.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: size, maxHeight: size)
        .clipShape(RoundedRectangle(cornerRadius: theme.radii.medium, style: .continuous))
        .task(id: attachment.id) {
            image = await store.thumbnail(for: attachment, pixelSize: Int(size * displayScale))
        }
    }
}
#endif
