import Foundation
#if canImport(Database)
import SwiftData

/// Where a draft goes on Save and a note on Delete. A protocol so the editor's model can be
/// tested against a store that fails.
@MainActor
protocol NoteSaving {
    /// Insert or update the note from the draft and save; returns what the store now holds.
    func save(_ draft: NoteDraft) throws -> NoteDraft.Saved
    /// Delete the note and save.
    func delete(id: UUID) throws
}

/// Saves on the app's context and, when the save fails, rolls that context back at once, so the
/// failed change can't ride along with a later unrelated save; the draft stays with the editor.
/// `modifiedAt` moves only when the text changed; `id` and `createdAt` never do.
@MainActor
final class NoteSaver: NoteSaving {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ draft: NoteDraft) throws -> NoteDraft.Saved {
        do {
            let note = try existing(draft.id) ?? inserted(draft)
            if note.title != draft.title || note.body != draft.body {
                note.title = draft.title
                note.body = draft.body
                note.modifiedAt = .now
            }
            try context.save()
            return NoteDraft.Saved(title: note.title, body: note.body, modifiedAt: note.modifiedAt)
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        do {
            guard let note = try existing(id) else { return }
            context.delete(note)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func existing(_ id: UUID) throws -> Note? {
        try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })).first
    }

    private func inserted(_ draft: NoteDraft) -> Note {
        // Empty text first, so the first save counts as a change and dates the note.
        let note = Note(id: draft.id, title: "", body: "", createdAt: draft.createdAt, modifiedAt: draft.createdAt)
        context.insert(note)
        return note
    }
}
#endif
