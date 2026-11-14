import SwiftUI
#if canImport(TabShell) && canImport(Database)
import SwiftData
import Theme

/// Home's newest notes, in the Notes tab's order, each opening its editor here on Home. With no
/// notes yet it says so and offers to write the first. See All switches to the Notes tab.
struct RecentNotesSection: View {
    static let limit = 3

    @Query(RecentNotesSection.recent) private var notes: [Note]
    @State private var drafts = NoteDrafts.shared
    /// The open editor's note or new draft, by id, as the Notes tab does it.
    @State private var opened: UUID?
    @Environment(\.modelContext) private var context

    private static var recent: FetchDescriptor<Note> {
        var descriptor = FetchDescriptor<Note>(sortBy: NotesView.order)
        descriptor.fetchLimit = limit
        return descriptor
    }

    var body: some View {
        HomeSection(tab: .notes, title: "Recent Notes", seeAll: notes.isEmpty ? nil : .notes) {
            if notes.isEmpty {
                HomeEmptyCard(message: "No notes yet. The ones you write show here, newest first.",
                              actionTitle: "Write a Note", systemImage: "square.and.pencil",
                              identifier: Identifiers.Home.notesEmpty, actionIdentifier: Identifiers.Home.writeNote) {
                    opened = drafts.newDraft().id
                }
            } else {
                ForEach(notes) { note in
                    if note.id != notes.first?.id {
                        Divider()
                    }
                    Button { opened = note.id } label: {
                        HomeRow(systemImage: "note.text", title: title(of: note),
                                detail: Text(note.modifiedAt, format: .dateTime.day().month().year()))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(Identifiers.Home.note(note.id.uuidString))
                }
            }
        }
        .navigationDestination(item: $opened, destination: editor)
    }

    private func title(of note: Note) -> Text {
        if let title = NoteText.displayTitle(title: note.title, body: note.body) {
            Text(verbatim: title)
        } else {
            Text("Untitled")
        }
    }

    /// The same editor the Notes tab opens, sharing its drafts; nothing for an id that is gone.
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
}
#endif
