import SwiftUI
#if canImport(Database) && canImport(Attachments)
import Attachments
import SwiftData
import Theme

/// The Library items a saved note refers to, in the note's order, with Add from the Library and
/// Remove on each. A reference never owns the item: removing one, or deleting the note, leaves the
/// item and its file; an item deleted from the Library leaves the note's text. A note not yet
/// saved can't refer to anything, and says so.
/// Accessibility identifiers: `notes.editor.addReference`, `notes.reference.<item id>`.
struct NoteReferencesSection: View {
    let noteID: UUID
    let isSaved: Bool
    @State private var references: [(reference: NoteLibraryReference, item: LibraryItem?)] = []
    @State private var isPicking = false
    @State private var failure: String?
    @Environment(\.modelContext) private var context
    @Environment(\.contentCoordinator) private var coordinator
    @Environment(\.appTheme) private var theme

    var body: some View {
        Section {
            if !isSaved {
                Text("Save the note to add items from your Library.")
                    .foregroundStyle(theme.colors.textSecondary)
            } else {
                ForEach(references, id: \.reference.id) { entry in
                    row(entry.item)
                        .accessibilityIdentifier(Identifiers.Notes.Editor.reference(entry.reference.itemID.uuidString))
                        .accessibilityAction(named: Text("Remove")) { unlink(entry.reference) }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { unlink(entry.reference) } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                }
                Button("Add from Library", systemImage: "books.vertical") { isPicking = true }
                    .accessibilityIdentifier(Identifiers.Notes.Editor.addReference)
                    // On the button, not the section: a Form's section presents nothing and runs no task.
                    .task(id: noteID) { reload() }
                    .sheet(isPresented: $isPicking, onDismiss: reload) {
                        LibraryItemPicker(excluding: Set(references.map(\.reference.itemID)), onPick: link)
                    }
                    .alert("Couldn't Change the Library Items", isPresented: $failure.isSome(), actions: { Button("OK") {} },
                           message: { Text(verbatim: failure ?? "") })
            }
        } header: {
            Text("Library Items")
        }
    }

    /// An item's title and kind, or the unavailable state for one no longer in the Library.
    @ViewBuilder
    private func row(_ item: LibraryItem?) -> some View {
        if let item {
            Label {
                Text(verbatim: item.title)
            } icon: {
                Image(systemName: item.attachment.isLink ? "link" : item.attachment.kind == .image ? "photo" : "doc")
            }
        } else {
            Label("Item no longer in the Library", systemImage: "questionmark.square.dashed")
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var note: Note? {
        let id = noteID
        return try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })).first
    }

    private func reload() {
        guard isSaved else {
            references = []
            return
        }
        do {
            let (coordinator, note) = try ready()
            references = try coordinator.items(for: note)
        } catch {
            failure = error.localizedDescription
        }
    }

    private func link(_ item: LibraryItem) {
        do {
            let (coordinator, note) = try ready()
            try coordinator.link(note, to: item)
            reload()
        } catch {
            failure = error.localizedDescription
        }
    }

    private func unlink(_ reference: NoteLibraryReference) {
        do {
            let (coordinator, note) = try ready()
            try coordinator.unlink(note, itemID: reference.itemID)
            reload()
        } catch {
            failure = error.localizedDescription
        }
    }

    /// The coordinator and the saved note, or why a change can't be made: never silently nothing.
    private func ready() throws -> (ContentCoordinator, Note) {
        guard let coordinator else { throw NotReady.noCoordinator }
        guard let note else { throw NotReady.noNote }
        return (coordinator, note)
    }

    private enum NotReady: LocalizedError {
        case noCoordinator, noNote

        var errorDescription: String? {
            switch self {
            case .noCoordinator: String(localized: "The Library isn't ready yet. Try again in a moment.")
            case .noNote: String(localized: "This note isn't saved yet.")
            }
        }
    }
}

/// The Library's items to choose from, those the note already refers to left out.
/// Accessibility identifiers: `notes.picker.item.<item id>`, `notes.picker.done`.
private struct LibraryItemPicker: View {
    let excluding: Set<UUID>
    let onPick: (LibraryItem) -> Void
    @Query(sort: \LibraryItem.createdAt, order: .reverse) private var items: [LibraryItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(items.filter { !excluding.contains($0.id) }) { item in
                    Button {
                        onPick(item)
                        dismiss()
                    } label: {
                        Label {
                            Text(verbatim: item.title)
                        } icon: {
                            Image(systemName: item.attachment.isLink ? "link" : item.attachment.kind == .image ? "photo" : "doc")
                        }
                    }
                    .accessibilityIdentifier(Identifiers.Notes.Picker.item(item.id.uuidString))
                }
            }
            .overlay {
                if items.isEmpty {
                    EmptyStateView(systemImage: "books.vertical", title: "Nothing in your Library yet",
                                   message: "Collect photos, files and links on the Library tab first.")
                }
            }
            .navigationTitle(Text("Add from Library"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(Identifiers.Notes.Picker.done)
                }
            }
        }
    }
}
#endif
