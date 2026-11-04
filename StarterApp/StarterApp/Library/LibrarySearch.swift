import Foundation
#if canImport(Database) && canImport(Attachments)

/// Search over the person's collection, in memory: the items are theirs, tens to hundreds, and the
/// attachment is a value inside the row that no predicate can reach. A match is on the title, the
/// file's name or a link's address, ignoring case and diacritics; the order is the caller's.
enum LibrarySearch {
    static func filter(_ items: [LibraryItem], matching query: String) -> [LibraryItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { matches($0, query) }
    }

    static func matches(_ item: LibraryItem, _ query: String) -> Bool {
        item.title.localizedStandardContains(query)
            || item.attachment.displayName.localizedStandardContains(query)
            || (item.attachment.url?.absoluteString.localizedStandardContains(query) ?? false)
    }
}
#endif
