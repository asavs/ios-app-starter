import QuickLook
import SwiftUI

public extension View {
    /// Previews the selected attachment: a stored file in Quick Look (paging through the others),
    /// a link in the browser. Quick Look clears the selection when dismissed.
    func attachmentPreview(_ selection: Binding<Attachment?>, in attachments: [Attachment],
                           store: any AttachmentStoring) -> some View {
        modifier(AttachmentPreviewModifier(selection: selection, attachments: attachments, store: store))
    }
}

struct AttachmentPreviewModifier: ViewModifier {
    @Binding var selection: Attachment?
    let attachments: [Attachment]
    let store: any AttachmentStoring
    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .quickLookPreview(previewURL, in: fileURLs)
            .onChange(of: selection, openLinkIfSelected)
    }

    private var fileURLs: [URL] {
        attachments.compactMap(store.fileURL)
    }

    /// Quick Look's binding: the selected file's URL, mapped back to the attachment it shows.
    private var previewURL: Binding<URL?> {
        Binding(get: { selection.flatMap(store.fileURL) },
                set: { url in selection = url.flatMap { url in attachments.first { store.fileURL(for: $0) == url } } })
    }

    private func openLinkIfSelected() {
        guard let selected = selection, selected.isLink, let url = selected.url else { return }
        openURL(url)
        selection = nil
    }
}
