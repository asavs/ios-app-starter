import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import StarterApp
#if canImport(Database) && canImport(Attachments)
import Attachments
import Database

/// Swift Testing has an `Attachment` of its own (a test attachment); this file means the module's.
private typealias Attachment = Attachments.Attachment

/// The Library's own logic: search over the collection, and collecting what the picker imported
/// through the coordinator, with a save that can't happen yet kept for a retry or discarded.
@MainActor
struct LibraryTests {
    private let container: ModelContainer
    private let files = RecordingFileStore()
    private let coordinator: ContentCoordinator

    init() throws {
        container = try Database.preview(schema: StarterDatabase.schema)
        coordinator = ContentCoordinator(context: container.mainContext, store: files)
    }

    private func photo(_ name: String) -> Attachment {
        Attachment(kind: .image, displayName: name, contentType: UTType.jpeg.identifier, byteCount: 1234,
                   relativePath: "\(UUID().uuidString).jpeg")
    }

    private func link(_ address: String, title: String) -> Attachment {
        Attachment(kind: .link, displayName: title, contentType: UTType.url.identifier, url: URL(string: address))
    }

    @Test func searchMatchesTitlesFileNamesAndLinkAddressesIgnoringCaseAndDiacritics() throws {
        let drill = try coordinator.collect(photo("IMG_0001.jpeg"), title: "Drill setup")
        let plan = try coordinator.collect(link("https://www.example.com/plan", title: "Training Plan"), title: "Training Plan")
        let notes = try coordinator.collect(photo("notes.pdf"), title: "Café")
        let all = [drill, plan, notes]
        #expect(LibrarySearch.filter(all, matching: "  ") == all, "Blank means everything, in the given order")
        #expect(LibrarySearch.filter(all, matching: "DRILL") == [drill])
        #expect(LibrarySearch.filter(all, matching: "example.com/") == [plan], "A link's address counts")
        #expect(LibrarySearch.filter(all, matching: "img_0001") == [drill], "So does the file's own name")
        #expect(LibrarySearch.filter(all, matching: "cafe") == [notes], "Diacritics are ignored")
        #expect(LibrarySearch.filter(all, matching: "nothing").isEmpty)
    }

    @Test func collectingSavesAnOwnerThroughTheCoordinator() throws {
        let collector = LibraryCollector(store: files)
        collector.coordinator = coordinator
        let attachment = photo("Capture")
        collector.collect([attachment])
        #expect(collector.unsaved.isEmpty)
        #expect(collector.failure == nil)
        let items = try container.mainContext.fetch(FetchDescriptor<LibraryItem>())
        #expect(items.map(\.title) == ["Capture"], "The item starts with the attachment's display name")
        #expect(try coordinator.owners(of: attachment.id) == 1)
    }

    @Test func anImportTheStoreCannotSaveYetIsKeptForRetryOrDiscarded() async throws {
        let collector = LibraryCollector(store: files)
        let first = photo("First")
        collector.collect([first])
        #expect(collector.unsaved == [first], "Nothing owns the file yet, so it is kept aside")
        #expect(collector.hasFailure)

        collector.coordinator = coordinator
        collector.retry()
        #expect(collector.unsaved.isEmpty)
        #expect(collector.failure == nil)
        #expect(try coordinator.owners(of: first.id) == 1, "Try Again saves the kept attachment")

        collector.coordinator = nil
        let second = photo("Second")
        collector.collect([second])
        await collector.discard().value
        #expect(collector.unsaved.isEmpty)
        #expect(collector.failure == nil)
        #expect(files.removed == [second.id], "Discard removes the file, since nothing owns it")
        #expect(try coordinator.owners(of: second.id) == 0)

        collector.hasFailure = false
        #expect(collector.failure == nil, "Dismissing the alert clears the message")
    }
}
#endif
