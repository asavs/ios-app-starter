import Foundation
#if canImport(Database) && canImport(Attachments)

/// What the Images tab and its viewer show of the Library: its photos, in the order given, and where
/// the viewer goes when the photo it shows is deleted.
enum ImageItems {
    /// The photos among `items`, in their order.
    static func images(in items: [LibraryItem]) -> [LibraryItem] {
        items.filter { $0.attachment.kind == .image }
    }

    /// The photo to show once `removed` is gone: the next one in `before` that is still in `after`,
    /// else the previous one, else nil (nothing is left, and the viewer closes).
    static func neighbor<ID: Equatable>(of removed: ID, in before: [ID], keeping after: [ID]) -> ID? {
        guard let index = before.firstIndex(of: removed) else { return after.first }
        return before[(index + 1)...].first(where: after.contains) ?? before[..<index].last(where: after.contains)
    }
}
#endif
