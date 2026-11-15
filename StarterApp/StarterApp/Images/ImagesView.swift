import SwiftUI
#if canImport(Database) && canImport(Attachments)
import Attachments
import SwiftData
import Theme

/// The Images tab: the photos in the Library, newest first, in the Attachments module's grid. Add
/// offers Photos and Camera only, with a Photos picker of photos alone, and collects each pick as a
/// Library item, so Home, Notes and the Library see it too. A tap opens the photo full screen in
/// `ImageViewer`; Remove on a cell asks before deleting.
/// Accessibility identifiers: `images.empty`, plus the module's grid and menu.
struct ImagesView: View {
    @Query(sort: \LibraryItem.createdAt, order: .reverse) private var items: [LibraryItem]
    @State private var collector: LibraryCollector
    @State private var picker: AttachmentPickerModel
    /// The grid's selection: an attachment, mapped to its item and cleared at once.
    @State private var selectedAttachment: Attachment?
    /// The photo the viewer opens on, by id.
    @State private var viewing: UUID?
    @State private var deleting: LibraryItem?
    @Environment(\.contentCoordinator) private var coordinator
    @Environment(\.appTheme) private var theme

    init() {
        let collector = LibraryCollector(store: StarterAttachments.store)
        _collector = State(initialValue: collector)
        _picker = State(initialValue: AttachmentPickerModel(store: StarterAttachments.store, sources: [.photos, .camera],
                                                            allowedContentTypes: [.image]) { added in
            collector.collect(added)
        })
    }

    var body: some View {
        let images = ImageItems.images(in: items)
        ScrollView {
            AttachmentGrid(images.map(\.attachment), store: StarterAttachments.store, selection: $selectedAttachment,
                           caption: { attachment in item(for: attachment, in: images)?.displayTitle },
                           onRemove: { attachment in deleting = item(for: attachment, in: images) })
                .padding()
        }
        .background(theme.colors.background)
        .overlay {
            if images.isEmpty {
                EmptyStateView(systemImage: "photo.on.rectangle", title: "No images yet",
                               message: "Pick photos from your library or take one. Add starts here.")
                    .accessibilityIdentifier(Identifiers.Images.empty)
            }
        }
        .navigationTitle(Text(StarterFeature.feature(.images).title))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AttachmentPicker(model: picker)
            }
        }
        .navigationDestination(item: $viewing, destination: ImageViewer.init(start:))
        .onChange(of: selectedAttachment, openSelected)
        .onChange(of: coordinatorID, initial: true, adoptCoordinator)
        .libraryDeleteConfirmation(item: $deleting)
        .alert("Couldn't Add the Image", isPresented: $collector.hasFailure) {
            Button("Try Again", action: collector.retry)
            Button("Discard", role: .destructive, action: discard)
        } message: {
            Text(verbatim: collector.failure ?? "")
        }
    }

    private func openSelected(_ old: Attachment?, _ attachment: Attachment?) {
        guard let attachment else { return }
        viewing = item(for: attachment, in: items)?.id
        selectedAttachment = nil
    }

    private func discard() {
        collector.discard()
    }

    /// The coordinator arrives after the first render (the root view's task creates it); the
    /// collector takes it whenever it changes.
    private var coordinatorID: ObjectIdentifier? {
        coordinator.map { ObjectIdentifier($0) }
    }

    private func adoptCoordinator() {
        collector.coordinator = coordinator
    }

    private func item(for attachment: Attachment, in items: [LibraryItem]) -> LibraryItem? {
        items.first { $0.attachment.id == attachment.id }
    }
}
#endif
