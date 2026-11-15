import SwiftUI
#if canImport(Database) && canImport(Attachments)
import Attachments
import SwiftData
import Theme

/// The Images tab's photos full screen, one at a time: swipe between them, in the grid's order,
/// with the tab bar out of the way. The bottom bar shares the original, opens the Library's detail
/// for the photo (title, size, Quick Look) and deletes it after asking; once a photo is gone, from
/// here or from its detail, the viewer moves to its neighbor, and closes when none is left.
/// Accessibility identifiers: `images.page.<attachment id>`, `images.viewer.share`, `.details`, `.delete`.
struct ImageViewer: View {
    @Query(sort: \LibraryItem.createdAt, order: .reverse) private var items: [LibraryItem]
    /// The page showing, by item id.
    @State private var current: UUID?
    @State private var details: UUID?
    @State private var deleting: LibraryItem?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    init(start: UUID) {
        _current = State(initialValue: start)
    }

    var body: some View {
        let images = ImageItems.images(in: items)
        let shown = images.first { $0.id == current }
        TabView(selection: $current) {
            ForEach(Array(images.enumerated()), id: \.element.id) { index, item in
                ImagePage(attachment: item.attachment, title: item.displayTitle, position: index + 1, count: images.count)
                    .tag(Optional(item.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(theme.colors.background)
        .navigationTitle(Text(verbatim: shown?.displayTitle ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if let shown {
                    if let file = StarterAttachments.store.fileURL(for: shown.attachment) {
                        ShareLink(item: file)
                            .accessibilityIdentifier(Identifiers.Images.share)
                    }
                    Spacer()
                    Button("Details", systemImage: "info.circle") { details = shown.id }
                        .accessibilityIdentifier(Identifiers.Images.details)
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = shown }
                        .accessibilityIdentifier(Identifiers.Images.delete)
                        // On the button, so a dialog shown as a popover (iOS 27) points at it.
                        .libraryDeleteConfirmation(item: $deleting)
                }
            }
        }
        .navigationDestination(item: $details) { id in
            if let item = images.first(where: { $0.id == id }) {
                LibraryItemView(item: item)
            }
        }
        .onChange(of: images.map(\.id), moveOffRemoved)
    }

    /// The photo showing left the Library: show its neighbor, or close with nothing left.
    private func moveOffRemoved(_ before: [UUID], _ after: [UUID]) {
        guard let current, !after.contains(current) else { return }
        if let next = ImageItems.neighbor(of: current, in: before, keeping: after) {
            self.current = next
        } else {
            dismiss()
        }
    }
}
#endif
