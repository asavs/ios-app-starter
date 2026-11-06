import Foundation
#if canImport(Database)

/// Search over the person's notes, in memory, the way the Library searches: a match is on the
/// title or the body, ignoring case and diacritics; the order is the caller's. Library content is
/// never searched from here.
enum NoteSearch {
    static func filter(_ notes: [Note], matching query: String) -> [Note] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return notes }
        return notes.filter { matches(title: $0.title, body: $0.body, query) }
    }

    static func matches(title: String, body: String, _ query: String) -> Bool {
        title.localizedStandardContains(query) || body.localizedStandardContains(query)
    }
}
#endif
