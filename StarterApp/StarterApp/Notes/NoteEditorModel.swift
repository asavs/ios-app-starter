import Foundation
import Observation
#if canImport(Database)

/// The editor's state: the draft, kept in `NoteDrafts` on every change, and what happened on
/// Save. A failed save keeps the draft and reports why; nothing is written until the person acts.
@MainActor @Observable
final class NoteEditorModel {
    var draft: NoteDraft {
        didSet { drafts.update(draft) }
    }
    /// The last save's failure, for the alert; nil once resolved.
    var failure: String?
    private let saver: any NoteSaving
    private let drafts: NoteDrafts

    init(draft: NoteDraft, saver: any NoteSaving, drafts: NoteDrafts = .shared) {
        self.draft = draft
        self.saver = saver
        self.drafts = drafts
    }

    var canSave: Bool { draft.canSave }
    var isDirty: Bool { draft.isDirty }

    /// Save the draft. On success the draft matches the store and leaves the drafts in progress.
    @discardableResult
    func save() -> Bool {
        do {
            draft.saved = try saver.save(draft)
            failure = nil
            return true
        } catch {
            failure = error.localizedDescription
            return false
        }
    }

    /// Drop the edits: a saved note goes back to its stored text, a new note to nothing.
    func discard() {
        if let saved = draft.saved {
            draft.title = saved.title
            draft.body = saved.body
        } else {
            draft.title = ""
            draft.body = ""
        }
        drafts.forget(draft.id)
        failure = nil
    }

    var hasFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }
}
#endif
