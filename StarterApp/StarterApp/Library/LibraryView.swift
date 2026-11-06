import SwiftUI
#if canImport(Database) && canImport(Attachments)
import Attachments
import SwiftData
import Theme

/// The Library tab: the photos, files and links a person collected, newest first, in the
/// Attachments module's grid with a search field above it. Add imports through the module's
/// picker menu and collects each new attachment as a `LibraryItem` through the content
/// coordinator; a tap opens the item's detail; Remove on a cell asks before deleting.
/// Accessibility identifiers: `library.empty`, `library.noResults`, plus the module's grid and menu.
struct LibraryView: View {
    @Query(sort: \LibraryItem.createdAt, order: .reverse) private var items: [LibraryItem]
    @State private var collector: LibraryCollector
    @State private var picker: AttachmentPickerModel
    @State private var search = ""
    /// The grid's selection: an attachment, mapped to its item and cleared at once.
    @State private var selectedAttachment: Attachment?
    /// The item whose detail is open, by id: a deleted item leaves the query, and the destination
    /// shows nothing rather than a model that no longer exists.
    @State private var opened: UUID?
    @State private var deleting: LibraryItem?
    @Environment(\.contentCoordinator) private var coordinator
    @Environment(\.appTheme) private var theme

    init() {
        let collector = LibraryCollector(store: StarterAttachments.store)
        _collector = State(initialValue: collector)
        _picker = State(initialValue: AttachmentPickerModel(store: StarterAttachments.store) { added in
            collector.collect(added)
        })
    }

    var body: some View {
        let shown: [LibraryItem] = LibrarySearch.filter(items, matching: search)
        ScrollView {
            collection(shown)
                .padding()
        }
        .background(theme.colors.background)
        .overlay { states(shown) }
        .navigationTitle(Text(StarterFeature.feature(.library).title))
        // Pinned under the title: the automatic placement shows no field at all inside a tab on iOS 27.
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Titles and links"))
        .toolbar { toolbar }
        .navigationDestination(item: $opened, destination: detail)
        .onChange(of: selectedAttachment, openSelected)
        .onChange(of: coordinatorID, initial: true, adoptCoordinator)
        .libraryDeleteConfirmation(item: $deleting)
        .alert("Couldn't Add to Your Library", isPresented: $collector.hasFailure, actions: failureActions, message: failureMessage)
    }

    /// The grid of what the search left, with each link's card under it.
    @ViewBuilder
    private func collection(_ shown: [LibraryItem]) -> some View {
        let attachments: [Attachment] = shown.map(\.attachment)
        let links: [LibraryItem] = shown.filter { $0.attachment.isLink }
        let caption: (Attachment) -> String? = { attachment in self.item(for: attachment, in: shown)?.title }
        let remove: (Attachment) -> Void = { attachment in self.deleting = self.item(for: attachment, in: shown) }
        VStack(alignment: .leading, spacing: theme.spacing.large) {
            if !shown.isEmpty {
                AttachmentGrid(attachments, store: StarterAttachments.store, selection: $selectedAttachment,
                               caption: caption, onRemove: remove)
                ForEach(links) { item in
                    LinkPreview(item.attachment, store: StarterAttachments.store)
                }
            }
        }
    }

    /// Nothing collected yet, or nothing matching the search.
    @ViewBuilder
    private func states(_ shown: [LibraryItem]) -> some View {
        if items.isEmpty {
            EmptyStateView(systemImage: "books.vertical", title: "Your Library is empty",
                           message: "Collect photos, files and links here to find them again. Add imports the first one.")
                .accessibilityIdentifier(Identifiers.Library.empty)
        } else if shown.isEmpty {
            ContentUnavailableView.search(text: search)
                .accessibilityIdentifier(Identifiers.Library.noResults)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            AttachmentPicker(model: picker)
        }
    }

    @ViewBuilder
    private func detail(_ id: UUID) -> some View {
        if let item = items.first(where: { $0.id == id }) {
            LibraryItemView(item: item)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func failureActions() -> some View {
        Button("Try Again", action: collector.retry)
        Button("Discard", role: .destructive) { collector.discard() }
    }

    private func failureMessage() -> Text {
        Text(verbatim: collector.failure ?? "")
    }

    private func openSelected(_ old: Attachment?, _ attachment: Attachment?) {
        guard let attachment else { return }
        opened = item(for: attachment, in: items)?.id
        selectedAttachment = nil
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
