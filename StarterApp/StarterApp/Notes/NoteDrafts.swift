import Foundation
import Observation
#if canImport(Database)

/// The drafts in progress, held above the editor: switching tabs, hiding the Notes tab or a
/// rebuilt shell leaves a draft where it was, and the list shows it as unsaved. In memory only,
/// so the process ending takes an unsaved draft with it; saved notes are in the store.
@MainActor @Observable
final class NoteDrafts {
    static let shared = NoteDrafts()

    private(set) var drafts: [UUID: NoteDraft] = [:]

    init() {}

    /// The draft for a saved note: the one in progress, or a fresh copy of the note.
    func draft(for note: Note) -> NoteDraft {
        drafts[note.id] ?? NoteDraft(note)
    }

    /// A new note's draft, kept here so the list can show it until it is saved or discarded.
    func newDraft() -> NoteDraft {
        let draft = NoteDraft()
        drafts[draft.id] = draft
        return draft
    }

    /// The editor's latest copy. A saved note's draft that matches the store again is forgotten; a
    /// new note's draft stays while its editor is open, blank or not, until Done or Discard.
    func update(_ draft: NoteDraft) {
        if draft.isSaved && !draft.isDirty {
            drafts[draft.id] = nil
        } else {
            drafts[draft.id] = draft
        }
    }

    func forget(_ id: UUID) {
        drafts[id] = nil
    }

    func isDirty(_ id: UUID) -> Bool {
        drafts[id]?.isDirty ?? false
    }

    /// New notes with text typed and not yet saved, newest first. A blank one isn't listed.
    var unsavedNew: [NoteDraft] {
        drafts.values.filter { !$0.isSaved && $0.isDirty }.sorted { $0.createdAt > $1.createdAt }
    }
}
#endif
