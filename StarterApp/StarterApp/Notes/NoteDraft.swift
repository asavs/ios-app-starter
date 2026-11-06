import Foundation
#if canImport(Database)

/// What the editor edits: a copy of a note's text, never the live model, so nothing reaches the
/// store until Save, and a failed save leaves the person's words where they are. `saved` holds the
/// values in the store, nil for a note that isn't there yet.
struct NoteDraft: Equatable, Identifiable {
    struct Saved: Equatable {
        var title: String
        var body: String
        var modifiedAt: Date
    }

    let id: UUID
    var title: String
    var body: String
    let createdAt: Date
    var saved: Saved?

    /// A new, empty note, not yet in the store.
    init(id: UUID = UUID(), createdAt: Date = .now) {
        self.id = id
        title = ""
        body = ""
        self.createdAt = createdAt
        saved = nil
    }

    /// A saved note, as stored.
    init(_ note: Note) {
        id = note.id
        title = note.title
        body = note.body
        createdAt = note.createdAt
        saved = Saved(title: note.title, body: note.body, modifiedAt: note.modifiedAt)
    }

    var isSaved: Bool { saved != nil }

    /// Nothing but whitespace in either field: not worth a record.
    var isBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Differs from the store: a saved note with edits, or a new note with anything typed.
    var isDirty: Bool {
        if let saved { return saved.title != title || saved.body != body }
        return !isBlank
    }

    var canSave: Bool { isDirty && !isBlank }

    /// The title, or the first line of the body for a body-only note; nil for a blank one.
    var displayTitle: String? { NoteText.displayTitle(title: title, body: body) }
}

enum NoteText {
    /// A row's title: the title as typed, else the first non-empty line of the body, else nil.
    static func displayTitle(title: String, body: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let line = body.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line.map { String($0.prefix(80)) }
    }
}
#endif
