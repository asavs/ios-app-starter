import SwiftUI
#if canImport(Database) && canImport(Attachments)
import Attachments
import Theme

/// One photo in `ImageViewer`, fitted to the screen and read from the original at the screen's
/// size, so it is sharp where the grid's cached thumbnail would be soft. VoiceOver reads its title
/// and where it is among the photos. Takes values, not the model, so a page on its way out after a
/// delete never reads a deleted item.
struct ImagePage: View {
    let attachment: Attachment
    let title: String
    let position: Int
    let count: Int
    /// The longer side of the page in points; zero until laid out.
    @State private var side: CGFloat = 0
    @State private var image: CGImage?
    @State private var isLoaded = false
    @Environment(\.displayScale) private var displayScale
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            if let image {
                Image(image, scale: displayScale, label: Text(verbatim: title))
                    .resizable()
                    .scaledToFit()
            } else if isLoaded {
                ContentUnavailableView("Can't Show This Photo", systemImage: "photo.badge.exclamationmark",
                                       description: Text("The original file is missing or unreadable."))
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(position) of \(count)"))
        .accessibilityIdentifier(Identifiers.Images.page(attachment.id.uuidString))
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(proxy.size.width, proxy.size.height)
        } action: { longer in
            side = longer
        }
        .task(id: side, load)
    }

    private func load() async {
        guard side > 0 else { return }
        image = await StarterAttachments.store.displayImage(for: attachment, pixelSize: Int(side * displayScale))
        isLoaded = true
    }
}
#endif
