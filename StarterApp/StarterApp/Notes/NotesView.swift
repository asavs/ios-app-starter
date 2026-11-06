import SwiftUI
#if canImport(Database)
import SwiftData
import Theme

/// The Notes tab: the person's notes, most recently changed first, under a search field, with
/// unsaved new drafts above them. Add opens an empty editor; a tap opens a note; a swipe or the
/// Delete action asks before deleting. Authored text lives here; collected files and links live
/// on the Library tab.
/// Accessibility identifiers: `notes.add`, `notes.empty`, `notes.noResults`, `notes.row.<id>`,
/// `notes.delete.confirm`.
struct NotesView: View {
    @Query(sort: [SortDescriptor(\Note.modifiedAt, order: .reverse), SortDescriptor(\Note.createdAt, order: .reverse)])
    private var notes: [Note]
    @State private var drafts = NoteDrafts.shared
    @State private var search = ""
    /// The note whose editor is open, by id: a deleted note leaves the query and the destination
    /// shows nothing rather than a model that no longer exists.
    @State private var opened: UUID?
    @State private var deleting: Note?
    @State private var failure: String?
    @Environment(\.modelContext) private var context
#if canImport(Attachments)
    @Environment(\.contentCoordinator) private var coordinator
#endif
    @Environment(\.appTheme) private var theme

    var body: some View {
        let shown: [Note] = NoteSearch.filter(notes, matching: search)
        let unsaved: [NoteDraft] = search.isEmpty ? drafts.unsavedNew : []
        List {
            if !unsaved.isEmpty {
                Section("Unsaved") {
                    ForEach(unsaved) { draft in
                        Button { opened = draft.id } label: {
                            NoteRow(title: draft.displayTitle, date: draft.createdAt, isUnsaved: true)
                        }
                        .accessibilityIdentifier(Identifiers.Notes.row(draft.id.uuidString))
                    }
                }
            }
            ForEach(shown) { note in
                Button { opened = note.id } label: {
                    NoteRow(title: NoteText.displayTitle(title: note.title, body: note.body), date: note.modifiedAt,
                            isUnsaved: drafts.isDirty(note.id))
                }
                .accessibilityIdentifier(Identifiers.Notes.row(note.id.uuidString))
                .accessibilityAction(named: Text("Delete")) { deleting = note }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { deleting = note } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .overlay { states(shown: shown, unsaved: unsaved) }
        .navigationTitle(Text(StarterFeature.feature(.notes).title))
        // Pinned under the title: the automatic placement shows no field at all inside a tab on iOS 27.
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Titles and text"))
        .toolbar { toolbar }
        .navigationDestination(item: $opened, destination: editor)
        .confirmationDialog("Delete this note?", isPresented: $deleting.isSome(), titleVisibility: .visible, presenting: deleting,
                            actions: deleteActions, message: deleteMessage)
        .alert("Couldn't Delete", isPresented: $failure.isSome(), actions: { Button("OK") {} },
               message: { Text(verbatim: failure ?? "") })
    }

    @ViewBuilder
    private func states(shown: [Note], unsaved: [NoteDraft]) -> some View {
        if notes.isEmpty && unsaved.isEmpty {
            EmptyStateView(systemImage: "note.text", title: "No notes yet", message: "Add writes the first one. Notes stay on this device.")
                .accessibilityIdentifier(Identifiers.Notes.empty)
        } else if shown.isEmpty && !search.isEmpty {
            ContentUnavailableView.search(text: search)
                .accessibilityIdentifier(Identifiers.Notes.noResults)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add", systemImage: "square.and.pencil", action: add)
                .accessibilityIdentifier(Identifiers.Notes.add)
        }
    }

    /// The editor for a saved note or an unsaved draft; nothing for an id that is neither.
    @ViewBuilder
    private func editor(_ id: UUID) -> some View {
        if let note = notes.first(where: { $0.id == id }) {
            NoteEditorView(model: NoteEditorModel(draft: drafts.draft(for: note), saver: NoteSaver(context: context), drafts: drafts))
        } else if let draft = drafts.drafts[id] {
            NoteEditorView(model: NoteEditorModel(draft: draft, saver: NoteSaver(context: context), drafts: drafts))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func deleteActions(_ note: Note) -> some View {
        Button("Delete", role: .destructive) { delete(note) }
            .accessibilityIdentifier(Identifiers.Notes.deleteConfirm)
        Button("Cancel", role: .cancel) {}
    }

    private func deleteMessage(_ note: Note) -> Text {
        Text("Items from your Library stay in the Library.")
    }

    private func add() {
        opened = drafts.newDraft().id
    }

    /// With Attachments the coordinator deletes the note and its references in one save; without
    /// it the saver deletes the note. Either way a failure leaves the note and says so.
    private func delete(_ note: Note) {
        drafts.forget(note.id)
        do {
#if canImport(Attachments)
            if let coordinator {
                try coordinator.deleteNote(note)
                return
            }
#endif
            try NoteSaver(context: context).delete(id: note.id)
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// One note in the list: its title (or the first line, or Untitled) and when it last changed,
/// one element for VoiceOver.
private struct NoteRow: View {
    let title: String?
    let date: Date
    let isUnsaved: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.extraSmall) {
            if let title {
                Text(verbatim: title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(2)
            } else {
                Text("Untitled")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            HStack(spacing: theme.spacing.small) {
                Text(date, format: .dateTime.day().month().year())
                if isUnsaved {
                    Label("Unsaved changes", systemImage: "pencil.line")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(theme.colors.warning)
                }
            }
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
#endif
