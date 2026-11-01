import Foundation
import UniformTypeIdentifiers

/// Something a person attached: a stored file (a photo, a capture, a document) or a link.
///
/// A value, so an app keeps it wherever it keeps its records (a `Codable` array on a SwiftData
/// model, for example). The bytes live in an `AttachmentStore`; `relativePath` names them under the
/// store's root, never as an absolute URL, because the sandbox container moves between installs.
/// Dates and sizes are recorded here so the store never reads them from the file system (the file
/// timestamp APIs need a privacy manifest reason).
public struct Attachment: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case image, movie, file, link
    }

    public var id: UUID
    public var kind: Kind
    /// What the person saw: the picked file's name, "Photo" with a date, or the link's title.
    public var displayName: String
    /// A `UTType` identifier, such as `public.jpeg`; `public.url` for a link.
    public var contentType: String
    /// The stored file's size; 0 for a link.
    public var byteCount: Int64
    public var createdAt: Date
    /// The file's path under the store's root; nil for a link.
    public var relativePath: String?
    /// The link; nil for a file.
    public var url: URL?

    public init(id: UUID = UUID(), kind: Kind, displayName: String, contentType: String, byteCount: Int64 = 0,
                createdAt: Date = .now, relativePath: String? = nil, url: URL? = nil) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.contentType = contentType
        self.byteCount = byteCount
        self.createdAt = createdAt
        self.relativePath = relativePath
        self.url = url
    }

    public var isLink: Bool { kind == .link }

    public var type: UTType? { UTType(contentType) }

    /// The kind a content type belongs to.
    public static func kind(of type: UTType?) -> Kind {
        guard let type else { return .file }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .movie }
        return .file
    }
}
