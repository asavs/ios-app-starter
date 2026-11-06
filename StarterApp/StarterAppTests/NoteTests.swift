import Foundation
import SwiftData
import Testing
@testable import StarterApp
#if canImport(Database)
import Database

/// Notes without a screen: the draft's rules, search, saving and deleting on a disk store that is
/// closed and reopened, and the editor's model against a store that fails.
@MainActor
struct NoteTests {
    private let directory: URL

    init() throws {
        directory = URL.temporaryDirectory.appending(path: "NoteTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func open() throws -> ModelContainer {
        try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self,
                          storage: .persistent(directory.appending(path: "notes.store")))
    }

    private func notes(in container: ModelContainer) throws -> [Note] {
        try container.mainContext.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    @Test func aDraftKnowsWhenItIsBlankDirtyAndSaveable() {
        var draft = NoteDraft()
        #expect(draft.isBlank && !draft.isDirty && !draft.canSave, "A new empty draft is nothing yet")
        draft.body = "  \n "
        #expect(draft.isBlank && !draft.canSave, "Whitespace is still nothing")
        draft.body = "Three rounds\nthen rest"
        #expect(draft.isDirty && draft.canSave)
        #expect(draft.displayTitle == "Three rounds", "A body-only note shows its first line")
        draft.title = " Monday "
        #expect(draft.displayTitle == "Monday")

        let note = Note(title: "Monday", body: "Rest day.")
        var existing = NoteDraft(note)
        #expect(existing.isSaved && !existing.isDirty && !existing.canSave, "As stored: nothing to save")
        existing.body = "Rest day!"
        #expect(existing.isDirty && existing.canSave)
        existing.body = "Rest day."
        #expect(!existing.isDirty, "Typing the stored text back makes it clean again")
        existing.title = ""
        existing.body = ""
        #expect(existing.isDirty && !existing.canSave, "Emptying a saved note is a change that can't be saved")
    }

    @Test func draftsInProgressOutliveTheEditorAndCleanOnesAreForgotten() {
        let drafts = NoteDrafts()
        var fresh = drafts.newDraft()
        #expect(drafts.drafts[fresh.id] != nil && drafts.unsavedNew.isEmpty, "A blank new draft is kept for its editor, not listed")
        drafts.update(fresh)
        #expect(drafts.drafts[fresh.id] != nil, "The editor's first write of empty text doesn't drop it")
        fresh.title = "Shopping"
        drafts.update(fresh)
        #expect(drafts.drafts[fresh.id]?.title == "Shopping")
        #expect(drafts.unsavedNew.map(\.id) == [fresh.id], "Listed once something is typed")
        let note = Note(title: "Monday", body: "Rest day.")
        var edited = drafts.draft(for: note)
        edited.body = "Rest day!"
        drafts.update(edited)
        #expect(drafts.isDirty(note.id))
        #expect(drafts.draft(for: note).body == "Rest day!", "Reopening the note resumes the draft")
        edited.body = "Rest day."
        drafts.update(edited)
        #expect(!drafts.isDirty(note.id) && drafts.drafts[note.id] == nil, "A draft matching the store is dropped")
        drafts.forget(fresh.id)
        #expect(drafts.unsavedNew.isEmpty)
    }

    @Test func searchMatchesTitlesAndBodiesIgnoringCaseAndDiacritics() {
        let plan = Note(title: "Training plan", body: "Three rounds.")
        let cafe = Note(title: "Café", body: "Order the beans.")
        let all = [plan, cafe]
        #expect(NoteSearch.filter(all, matching: " ") == all)
        #expect(NoteSearch.filter(all, matching: "ROUNDS") == [plan], "The body counts")
        #expect(NoteSearch.filter(all, matching: "cafe") == [cafe], "Diacritics are ignored")
        #expect(NoteSearch.filter(all, matching: "nothing").isEmpty)
    }

    @Test func savingCreatesUpdatesAndDatesNotesThatSurviveReopening() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        var id: UUID
        var createdAt: Date
        do {
            let container = try open()
            let saver = NoteSaver(context: container.mainContext)
            var draft = NoteDraft()
            draft.title = "Monday"
            draft.body = "Three rounds."
            let saved = try saver.save(draft)
            draft.saved = saved
            id = draft.id
            createdAt = draft.createdAt
            #expect(saved.title == "Monday" && saved.body == "Three rounds.")
            #expect(!draft.isDirty, "What came back matches the draft")

            let unchanged = try saver.save(draft)
            #expect(unchanged.modifiedAt == saved.modifiedAt, "Saving the same text again doesn't move the date")

            draft.body = "Four rounds."
            let changed = try saver.save(draft)
            #expect(changed.modifiedAt > saved.modifiedAt, "A change moves the date")
            #expect(try notes(in: container).count == 1, "Updates don't duplicate")
        }
        let reopened = try open()
        let stored = try notes(in: reopened)
        #expect(stored.map(\.id) == [id])
        #expect(stored.first?.body == "Four rounds." && stored.first?.createdAt == createdAt, "The note, its id and its creation date survive a reopen")
        try NoteSaver(context: reopened.mainContext).delete(id: id)
        #expect(try notes(in: reopened).isEmpty)
        try NoteSaver(context: reopened.mainContext).delete(id: id)
        #expect(true, "Deleting a note that is already gone is nothing")
    }

    @Test func aFailedSaveKeepsTheDraftAndRetrySucceeds() {
        let store = FlakyNoteStore()
        let drafts = NoteDrafts()
        let model = NoteEditorModel(draft: NoteDraft(), saver: store, drafts: drafts)
        model.draft.title = "Monday"
        model.draft.body = "Three rounds."
        store.failures = 1
        #expect(model.save() == false)
        #expect(model.hasFailure, "The person is told")
        #expect(model.draft.title == "Monday" && model.draft.body == "Three rounds.", "And keeps the text")
        #expect(!model.draft.isSaved && drafts.isDirty(model.draft.id), "The draft is still in progress")
        #expect(model.save(), "Try Again")
        #expect(!model.hasFailure && model.draft.isSaved && !model.draft.isDirty)
        #expect(store.saved.map(\.title) == ["Monday"], "Saved once")

        model.draft.body = "Four rounds."
        #expect(drafts.isDirty(model.draft.id))
        model.discard()
        #expect(model.draft.body == "Three rounds." && !drafts.isDirty(model.draft.id), "Discard goes back to the stored text")
    }
}

/// Saves into memory; `failures` makes the next saves throw.
@MainActor
private final class FlakyNoteStore: NoteSaving {
    var failures = 0
    private(set) var saved: [NoteDraft] = []

    struct Failure: LocalizedError {
        var errorDescription: String? { "The disk is full." }
    }

    func save(_ draft: NoteDraft) throws -> NoteDraft.Saved {
        if failures > 0 {
            failures -= 1
            throw Failure()
        }
        saved.append(draft)
        return NoteDraft.Saved(title: draft.title, body: draft.body, modifiedAt: .now)
    }

    func delete(id: UUID) throws {
        saved.removeAll { $0.id == id }
    }
}
#endif
