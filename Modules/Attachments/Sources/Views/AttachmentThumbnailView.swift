import SwiftUI
import Theme

/// A stored file's thumbnail from the store, loaded once the cell appears; a symbol for a link or
/// while loading. Decorative: the cell carries the description. The image fills whatever frame the
/// cell gives it, so the cell clips.
struct AttachmentThumbnailView: View {
    let attachment: Attachment
    let store: any AttachmentStoring
    let pixelSize: Int
    @State private var image: CGImage?
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            theme.colors.surface
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: symbolName)
                    .font(.title)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .task(id: attachment.id) { await load() }
    }

    private var symbolName: String {
        switch attachment.kind {
        case .image: "photo"
        case .movie: "film"
        case .file: "doc"
        case .link: "link"
        }
    }

    private func load() async {
        guard !attachment.isLink else { return }
        image = await store.thumbnail(for: attachment, pixelSize: pixelSize)
    }
}
