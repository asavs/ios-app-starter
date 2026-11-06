import Foundation
#if canImport(Database) && canImport(Attachments)
import Attachments
import Database
import SwiftData

/// Every change that touches an attachment's ownership goes through here: collecting into the
/// Library, linking notes to items, deleting items, notes and presets, removing an attachment from a
/// preset, and the file cleanup that follows. The rule (docs/research/content-ownership.md): a file
/// goes only after the record change that released its last owner has been saved, and the intent to
/// delete it is saved in that same transaction, so a crash in between is retried on the next launch
/// instead of leaving the file behind. Owners are every persisted Library item and every preset's
/// attachment list, hidden tabs included. A note's reference to an item is never an owner.
///
/// Main actor, like the model context it works on; `AttachmentStore` is an actor of its own and only
/// ever receives `Attachment` values from here.
@MainActor
final class ContentCoordinator {
    let context: ModelContext
    private let store: any AttachmentStoring
    /// Attachments whose files exist but whose owner hasn't been saved yet: cleanup leaves them alone.
    private(set) var inFlightImports: Set<Attachment.ID> = []
    private var cleanup: Task<Void, Never>?

    init(context: ModelContext, store: any AttachmentStoring) {
        self.context = context
        self.store = store
    }

    // MARK: Owners

    /// How many persisted records own the attachment: presets listing it plus Library items holding
    /// it. `ignoring` leaves out records being deleted in the same change, which a fetch may still
    /// return before the save.
    func owners(of attachmentID: Attachment.ID, ignoring: Set<PersistentIdentifier> = []) throws -> Int {
        let presets = try context.fetch(FetchDescriptor<TimerPreset>())
            .filter { !ignoring.contains($0.persistentModelID) && $0.attachments.contains { $0.id == attachmentID } }
        let items = try context.fetch(FetchDescriptor<LibraryItem>())
            .filter { !ignoring.contains($0.persistentModelID) && $0.attachment.id == attachmentID }
        return presets.count + items.count
    }

    // MARK: Imports

    /// A file is being stored for a record not yet saved. Call before the store adds it.
    func beginImport(_ id: Attachment.ID) { inFlightImports.insert(id) }

    /// The owner is saved (or the import was abandoned and the file removed).
    func endImport(_ id: Attachment.ID) { inFlightImports.remove(id) }

    // MARK: Library

    /// Collect a stored attachment as a Library item, saving the owner. The attachment must already be
    /// in the store; its id leaves the in-flight set once the item is saved.
    @discardableResult
    func collect(_ attachment: Attachment, title: String) throws -> LibraryItem {
        let item = LibraryItem(title: title, attachment: attachment)
        context.insert(item)
        try saveOrRollback()
        endImport(attachment.id)
        return item
    }

    /// How many notes refer to the item: what a delete confirmation tells the person.
    func referenceCount(to item: LibraryItem) throws -> Int {
        let id = item.id
        return try context.fetchCount(FetchDescriptor<NoteLibraryReference>(predicate: #Predicate { $0.itemID == id }))
    }

    /// Delete a collected item: its references go, the notes' text stays, and its file goes once
    /// nothing else owns the attachment (a preset may). One save for the records and the cleanup intent.
    func deleteLibraryItem(_ item: LibraryItem) throws {
        let id = item.id
        for reference in try context.fetch(FetchDescriptor<NoteLibraryReference>(predicate: #Predicate { $0.itemID == id })) {
            context.delete(reference)
        }
        let attachment = item.attachment
        let remaining = try owners(of: attachment.id, ignoring: [item.persistentModelID])
        context.delete(item)
        if remaining == 0 { context.insert(PendingAttachmentDeletion(attachment: attachment)) }
        try saveOrRollback()
        if remaining == 0 { scheduleCleanup() }
    }

    // MARK: Notes

    /// Link a note to an item, once per pair; the link takes the next position in the note.
    /// Returns false when the pair already exists.
    @discardableResult
    func link(_ note: Note, to item: LibraryItem) throws -> Bool {
        let noteID = note.id, itemID = item.id
        let existing = try context.fetch(FetchDescriptor<NoteLibraryReference>(predicate: #Predicate { $0.noteID == noteID }))
        guard !existing.contains(where: { $0.itemID == itemID }) else { return false }
        // After the next existing order, not the count: an unlink in the middle must not make two references share one.
        let order = (existing.map(\.order).max() ?? -1) + 1
        context.insert(NoteLibraryReference(noteID: noteID, itemID: itemID, order: order))
        try saveOrRollback()
        return true
    }

    /// Remove a note's link to an item. The item and its file stay.
    func unlink(_ note: Note, from item: LibraryItem) throws {
        try unlink(note, itemID: item.id)
    }

    /// The same by the item's id, for a reference whose item is no longer in the Library.
    func unlink(_ note: Note, itemID: UUID) throws {
        let noteID = note.id
        for reference in try context.fetch(FetchDescriptor<NoteLibraryReference>(predicate: #Predicate { $0.noteID == noteID && $0.itemID == itemID })) {
            context.delete(reference)
        }
        try saveOrRollback()
    }

    /// The items a note refers to, in the note's order; a missing target is reported as nil in place
    /// so the screen can show an unavailable item rather than another item with the same name.
    func items(for note: Note) throws -> [(reference: NoteLibraryReference, item: LibraryItem?)] {
        let noteID = note.id
        let references = try context.fetch(FetchDescriptor<NoteLibraryReference>(predicate: #Predicate { $0.noteID == noteID },
                                                                                 sortBy: [SortDescriptor(\.order)]))
        let items = try context.fetch(FetchDescriptor<LibraryItem>())
        return references.map { reference in (reference, items.first { $0.id == reference.itemID }) }
    }

    /// Delete a note and its references. Items and files are untouched.
    func deleteNote(_ note: Note) throws {
        let noteID = note.id
        for reference in try context.fetch(FetchDescriptor<NoteLibraryReference>(predicate: #Predicate { $0.noteID == noteID })) {
            context.delete(reference)
        }
        context.delete(note)
        try saveOrRollback()
    }

    // MARK: Presets

    /// Take an attachment off a preset; its file goes once nothing else owns it.
    func removeAttachment(_ attachment: Attachment, from preset: TimerPreset) throws {
        preset.attachments.removeAll { $0.id == attachment.id }
        let remaining = try owners(of: attachment.id)
        if remaining == 0 { context.insert(PendingAttachmentDeletion(attachment: attachment)) }
        try saveOrRollback()
        if remaining == 0 { scheduleCleanup() }
    }

    /// Delete a preset; each attachment's file goes once nothing else owns it.
    func deletePreset(_ preset: TimerPreset) throws {
        let attachments = preset.attachments
        let ignoring: Set<PersistentIdentifier> = [preset.persistentModelID]
        var released = false
        for attachment in attachments where try owners(of: attachment.id, ignoring: ignoring) == 0 {
            context.insert(PendingAttachmentDeletion(attachment: attachment))
            released = true
        }
        context.delete(preset)
        try saveOrRollback()
        if released { scheduleCleanup() }
    }

    // MARK: Saving

    /// Save, or roll the context back so a failed change can't ride along with a later unrelated
    /// save; the caller reports the error and the records are as they were.
    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    // MARK: Cleanup

    /// Run the pending deletions now: on launch, and after each change that queued one. Entries whose
    /// attachment gained an owner meanwhile, or is being imported, are left alone or dropped; a
    /// removal that fails keeps its entry with the error for the next attempt. Serialized, so two
    /// changes in a row can't remove the same file twice.
    func processPendingDeletions() async {
        let previous = cleanup
        let task = Task { [weak self] in
            await previous?.value
            await self?.processPendingDeletionsNow()
        }
        cleanup = task
        await task.value
    }

    private func scheduleCleanup() {
        let previous = cleanup
        cleanup = Task { [weak self] in
            await previous?.value
            await self?.processPendingDeletionsNow()
        }
    }

    private func processPendingDeletionsNow() async {
        guard let pending = try? context.fetch(FetchDescriptor<PendingAttachmentDeletion>(sortBy: [SortDescriptor(\.requestedAt)])) else { return }
        for entry in pending {
            let attachment = entry.attachment
            if inFlightImports.contains(attachment.id) { continue } // An import may own it in a moment.
            if (try? owners(of: attachment.id)) ?? 1 > 0 {
                context.delete(entry) // Collected or attached again before the file went: keep the file.
                try? context.save()
                continue
            }
            do {
                try await store.remove(attachment)
                context.delete(entry)
            } catch {
                entry.attempts += 1
                entry.lastError = String(describing: error)
            }
            try? context.save()
        }
    }

    /// Deletions still owed: what a Settings row or a test shows. Empty when every file is gone.
    func pendingDeletions() throws -> [PendingAttachmentDeletion] {
        try context.fetch(FetchDescriptor<PendingAttachmentDeletion>(sortBy: [SortDescriptor(\.requestedAt)]))
    }
}
#endif
