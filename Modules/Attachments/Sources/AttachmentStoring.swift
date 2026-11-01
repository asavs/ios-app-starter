import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// What the views need from the store, so previews and tests can use a temporary one.
public protocol AttachmentStoring: Sendable {
    /// Copy a file in (a picked document, a photo the picker exported) and describe it.
    func add(copying source: URL, displayName: String?, contentType: UTType?) async throws -> Attachment
    /// Store encoded image bytes (a camera capture) as a new file.
    func add(imageData: Data, contentType: UTType, displayName: String) async throws -> Attachment
    /// Record a link, fetching and caching its metadata once.
    func add(link: URL) async throws -> Attachment
    /// Where a stored file is; nil for a link.
    func fileURL(for attachment: Attachment) -> URL?
    /// A small image for a grid cell, made once and cached; nil for a link or an unreadable file.
    func thumbnail(for attachment: Attachment, pixelSize: Int) async -> CGImage?
    /// The link's cached metadata as a secure-coding archive of `LPLinkMetadata`; nil for a file.
    func linkMetadataArchive(for attachment: Attachment) async -> Data?
    /// Delete the file and everything cached for it.
    func remove(_ attachment: Attachment) async throws
    /// Delete every stored file whose attachment the app no longer references; returns how many.
    func sweep(keeping ids: Set<Attachment.ID>) async throws -> Int
}
