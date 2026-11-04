import CoreGraphics
import Foundation
import UniformTypeIdentifiers
#if canImport(Database) && canImport(Attachments)
import Attachments

/// Records removals; `failures` makes the next removals throw.
/// Used by `ContentCoordinatorTests` and `LibraryTests`.
final class RecordingFileStore: AttachmentStoring, @unchecked Sendable {
    private(set) var removed: [Attachments.Attachment.ID] = []
    var failures = 0

    struct Failure: Error {}

    func add(copying source: URL, displayName: String?, contentType: UTType?) async throws -> Attachments.Attachment { fatalError("unused") }
    func add(imageData: Data, contentType: UTType, displayName: String) async throws -> Attachments.Attachment { fatalError("unused") }
    func add(link: URL) async throws -> Attachments.Attachment { fatalError("unused") }
    func fileURL(for attachment: Attachments.Attachment) -> URL? { nil }
    func thumbnail(for attachment: Attachments.Attachment, pixelSize: Int) async -> CGImage? { nil }
    func linkMetadataArchive(for attachment: Attachments.Attachment) async -> Data? { nil }
    func remove(_ attachment: Attachments.Attachment) async throws {
        if failures > 0 { failures -= 1; throw Failure() }
        removed.append(attachment.id)
    }
    func sweep(keeping ids: Set<Attachments.Attachment.ID>) async throws -> Int { 0 }
}
#endif
