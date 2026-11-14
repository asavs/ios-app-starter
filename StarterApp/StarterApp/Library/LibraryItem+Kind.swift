import Foundation
#if canImport(Database) && canImport(Attachments)
import Attachments

/// How an item reads where it is listed or described: its kind in words and a symbol for it.
/// The detail screen and Home's recent items share these, so the two never disagree.
extension LibraryItem {
    var kindName: String {
        switch attachment.kind {
        case .image: String(localized: "Photo")
        case .movie: String(localized: "Video")
        case .file: attachment.type?.localizedDescription ?? String(localized: "File")
        case .link: String(localized: "Link")
        }
    }

    var kindSymbol: String {
        switch attachment.kind {
        case .image: "photo"
        case .movie: "film"
        case .file: "doc"
        case .link: "link"
        }
    }

    /// The title as typed, else the file's name or the link's address, so a row never reads blank.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? attachment.displayName : trimmed
    }
}
#endif
