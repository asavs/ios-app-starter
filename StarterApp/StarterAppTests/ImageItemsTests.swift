import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import StarterApp
#if canImport(Database) && canImport(Attachments)
import Attachments
import Database

/// The Images tab's view of the Library: photos only, in the given order, and where the viewer goes
/// when the photo it shows is deleted.
@MainActor
struct ImageItemsTests {
    private let container: ModelContainer
    private let coordinator: ContentCoordinator

    init() throws {
        container = try Database.preview(schema: StarterDatabase.schema)
        coordinator = ContentCoordinator(context: container.mainContext, store: RecordingFileStore())
    }

    private func collect(_ kind: Attachments.Attachment.Kind, _ name: String, type: UTType) throws -> LibraryItem {
        let attachment = Attachments.Attachment(kind: kind, displayName: name, contentType: type.identifier,
                                                byteCount: 10, relativePath: "\(UUID().uuidString).\(type.preferredFilenameExtension ?? "bin")")
        return try coordinator.collect(attachment, title: name)
    }

    @Test func onlyPhotosInTheGivenOrder() throws {
        let first = try collect(.image, "First", type: .jpeg)
        let movie = try collect(.movie, "Clip", type: .quickTimeMovie)
        let document = try collect(.file, "Plan", type: .pdf)
        let second = try collect(.image, "Second", type: .heic)
        #expect(ImageItems.images(in: [second, document, movie, first]).map(\.id) == [second.id, first.id])
    }

    @Test func theNeighborIsTheNextThenThePreviousThenNothing() {
        let ids = ["a", "b", "c"]
        #expect(ImageItems.neighbor(of: "b", in: ids, keeping: ["a", "c"]) == "c", "The next one first")
        #expect(ImageItems.neighbor(of: "c", in: ids, keeping: ["a", "b"]) == "b", "At the end, the previous one")
        #expect(ImageItems.neighbor(of: "a", in: ids, keeping: ["c"]) == "c", "Skipping any that went too")
        #expect(ImageItems.neighbor(of: "a", in: ["a"], keeping: []) == nil, "Nothing left: the viewer closes")
    }
}
#endif
