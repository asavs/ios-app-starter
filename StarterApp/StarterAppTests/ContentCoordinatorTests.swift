import CoreGraphics
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

/// Ownership and cleanup through the coordinator, against an in-memory store and a recording file
/// store: files go only after the record change that released their last owner, and never while
/// another record (a preset, another item) or an import in flight still needs them.
@MainActor
struct ContentCoordinatorTests {
    private let container: ModelContainer
    private let files = RecordingFileStore()
    private let coordinator: ContentCoordinator

    init() throws {
        container = try Database.preview(schema: StarterDatabase.schema)
        coordinator = ContentCoordinator(context: container.mainContext, store: files)
    }

    private func photo(_ name: String = "Capture") -> Attachment {
        Attachment(kind: .image, displayName: name, contentType: "public.jpeg", byteCount: 1234, relativePath: "\(UUID().uuidString).jpeg")
    }

    private func pending() throws -> [PendingAttachmentDeletion] { try coordinator.pendingDeletions() }

    @Test func deletingAnUnreferencedItemRemovesItsFileOnceTheRecordIsSaved() async throws {
        let attachment = photo()
        let item = try coordinator.collect(attachment, title: "Drill")
        #expect(try coordinator.owners(of: attachment.id) == 1)
        try coordinator.deleteLibraryItem(item)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<LibraryItem>()) == 0, "The record is gone")
        await coordinator.processPendingDeletions()
        #expect(files.removed == [attachment.id], "The file went once, after the save")
        #expect(try pending().isEmpty, "The cleanup intent is cleared")
    }

    @Test func linkingAfterAnUnlinkKeepsTheOrdersUniqueAndTheSequenceStable() throws {
        let note = Note(title: "Plan", body: "")
        container.mainContext.insert(note)
        try container.mainContext.save()
        let first = try coordinator.collect(photo("First"), title: "First")
        let second = try coordinator.collect(photo("Second"), title: "Second")
        let third = try coordinator.collect(photo("Third"), title: "Third")
        let fourth = try coordinator.collect(photo("Fourth"), title: "Fourth")
        for item in [first, second, third] { try coordinator.link(note, to: item) }
        try coordinator.unlink(note, from: second)
        try coordinator.link(note, to: fourth)
        let listed = try coordinator.items(for: note)
        #expect(listed.map { $0.item?.title } == ["First", "Third", "Fourth"], "The remaining order, then the new one last")
        #expect(Set(listed.map(\.reference.order)).count == 3, "No two references share an order")
        try coordinator.unlink(note, itemID: fourth.id)
        #expect(try coordinator.items(for: note).count == 2, "Unlinking by id works for an item that may be gone")
    }

    @Test func aNoteNeverOwnsAnItemAndDeletingTheItemKeepsTheNotesText() async throws {
        let attachment = photo()
        let item = try coordinator.collect(attachment, title: "Plan page")
        let first = Note(title: "Monday", body: "Three rounds.")
        let second = Note(title: "Tuesday", body: "Rest day.")
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()
        #expect(try coordinator.link(first, to: item))
        #expect(try coordinator.link(first, to: item) == false, "One reference per pair")
        #expect(try coordinator.link(second, to: item))
        #expect(try coordinator.referenceCount(to: item) == 2)
        #expect(try coordinator.owners(of: attachment.id) == 1, "References don't count as owners")

        try coordinator.deleteNote(first)
        #expect(try coordinator.referenceCount(to: item) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<LibraryItem>()) == 1, "Deleting a note leaves the item")
        #expect(files.removed.isEmpty, "And its file")

        try coordinator.deleteLibraryItem(item)
        await coordinator.processPendingDeletions()
        let notes = try container.mainContext.fetch(FetchDescriptor<Note>())
        #expect(notes.map(\.body) == ["Rest day."], "The remaining note keeps its text")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<NoteLibraryReference>()) == 0, "Its reference to the item is gone")
        #expect(try coordinator.items(for: second).isEmpty)
        #expect(files.removed == [attachment.id])
    }

    @Test func aFileSharedWithAPresetStaysUntilThePresetReleasesItToo() async throws {
        let attachment = photo()
        let preset = TimerPreset(name: "Tabata", plan: "intervals", work: 20, rest: 10, rounds: 8, attachments: [attachment])
        container.mainContext.insert(preset)
        try container.mainContext.save()
        let item = try coordinator.collect(attachment, title: "Drill")
        #expect(try coordinator.owners(of: attachment.id) == 2)

        try coordinator.deleteLibraryItem(item)
        await coordinator.processPendingDeletions()
        #expect(files.removed.isEmpty, "The preset still owns the file")
        #expect(try pending().isEmpty, "No cleanup was queued")

        try coordinator.removeAttachment(attachment, from: preset)
        await coordinator.processPendingDeletions()
        #expect(files.removed == [attachment.id], "The last owner released it")
        #expect(preset.attachments.isEmpty)
    }

    @Test func deletingAPresetReleasesOnlyTheFilesNothingElseOwns() async throws {
        let shared = photo("Shared"), own = photo("Own")
        let preset = TimerPreset(name: "Mine", plan: "intervals", work: 20, rest: 10, rounds: 3, attachments: [shared, own])
        container.mainContext.insert(preset)
        try container.mainContext.save()
        try coordinator.collect(shared, title: "Also in the Library")
        try coordinator.deletePreset(preset)
        await coordinator.processPendingDeletions()
        #expect(files.removed == [own.id], "The shared file stays with the Library item")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TimerPreset>()) == 0)
        #expect(try pending().isEmpty)
    }

    @Test func aFailedRemovalKeepsTheIntentAndRetriesLater() async throws {
        let attachment = photo()
        let item = try coordinator.collect(attachment, title: "Drill")
        // Deleting schedules a cleanup pass of its own; the explicit call below is a second pass.
        files.failures = 2
        try coordinator.deleteLibraryItem(item)
        await coordinator.processPendingDeletions()
        let kept = try #require(try pending().first, "The entry survives the failures")
        #expect(kept.attempts == 2 && kept.lastError != nil, "Each failed pass is counted")
        #expect(files.removed.isEmpty)

        await coordinator.processPendingDeletions() // The next launch, or the next change.
        #expect(files.removed == [attachment.id])
        #expect(try pending().isEmpty)
    }

    @Test func anAttachmentCollectedAgainBeforeCleanupKeepsItsFile() async throws {
        let attachment = photo()
        let item = try coordinator.collect(attachment, title: "Drill")
        try coordinator.deleteLibraryItem(item)
        #expect(try pending().count == 1)
        // Before cleanup runs, the same stored file is collected again (say from the preset's screen).
        try coordinator.collect(attachment, title: "Drill again")
        await coordinator.processPendingDeletions()
        #expect(files.removed.isEmpty, "An owner appeared before the file went")
        #expect(try pending().isEmpty, "The stale intent is dropped")
    }

    @Test func anImportInFlightIsNeverCleanedUp() async throws {
        let attachment = photo()
        coordinator.beginImport(attachment.id)
        // A stale intent for the same id (an earlier owner released it) must wait for the import.
        container.mainContext.insert(PendingAttachmentDeletion(attachment: attachment))
        try container.mainContext.save()
        await coordinator.processPendingDeletions()
        #expect(files.removed.isEmpty)
        #expect(try pending().count == 1, "Left for the next pass")
        try coordinator.collect(attachment, title: "Imported")
        #expect(coordinator.inFlightImports.isEmpty, "Saving the owner ends the import")
        await coordinator.processPendingDeletions()
        #expect(files.removed.isEmpty, "Owned now: the file stays")
        #expect(try pending().isEmpty, "And the intent is dropped")
    }

    @Test func unlinkingKeepsTheItemAndAMissingTargetIsReportedInPlace() throws {
        let item = try coordinator.collect(photo(), title: "Plan")
        let note = Note(title: "Notes", body: "")
        container.mainContext.insert(note)
        try container.mainContext.save()
        try coordinator.link(note, to: item)
        try coordinator.unlink(note, from: item)
        #expect(try coordinator.referenceCount(to: item) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<LibraryItem>()) == 1)

        // A reference whose item is gone (an integrity error) shows as unavailable, never as another item.
        container.mainContext.insert(NoteLibraryReference(noteID: note.id, itemID: UUID(), order: 0))
        try container.mainContext.save()
        let listed = try coordinator.items(for: note)
        #expect(listed.count == 1 && listed[0].item == nil)
    }
}
#endif
