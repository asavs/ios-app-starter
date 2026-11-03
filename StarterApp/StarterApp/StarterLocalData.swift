import Foundation
#if canImport(Settings)
import Settings
#if canImport(Onboarding)
import Onboarding
#endif
#if canImport(Database)
import Database
import SwiftData
#endif
#if canImport(Attachments)
import Attachments
#endif

/// Everything the template keeps on the device, for the Erase Local Data row. A module that adds a
/// store adds a step here. Main actor, like the Settings view that asks for it and the defaults it reads.
///
/// Order: the settings, secrets and tips first (idempotent, nothing depends on them), then the
/// database's records, verified empty, then the attachment files and caches. The last two are
/// journaled (`ResetJournal`), so an erase the app didn't finish is completed on the next launch
/// before anything seeds or imports; the files never go before the records that name them.
@MainActor
enum StarterLocalData {
#if canImport(Database)
    /// - Parameters:
    ///   - database: The open container; its records go too. Seeded sample content comes back on the
    ///     next launch, as on a fresh install.
    ///   - journal: Where the erase records its progress; the app's by default.
    static func reset(database: ModelContainer?, journal: ResetJournal = .standard) -> LocalDataReset {
        var reset = reset(journal: journal)
        guard let database else { return reset }
        // The journaled phases replace the plain file step: records first, then files, then the
        // journal closes. A failed phase keeps the journal, and the next launch picks it up.
        reset.steps.removeAll { $0.name == "attachments" }
        reset.steps.append(LocalDataReset.Step("database") {
            try journal.begin(.records)
            try eraseRecords(in: database)
        })
        reset.steps.append(LocalDataReset.Step("attachments") {
            try journal.begin(.files)
            try eraseFiles()
            try journal.finish()
        })
        return reset
    }

    /// Finish an erase the last run left unfinished: the phases from the one it was in. Call at
    /// launch, before seeding. Nothing to do when the journal is clear.
    static func recoverUnfinishedErase(database: ModelContainer, journal: ResetJournal = .standard) throws {
        for phase in journal.owedPhases {
            try journal.begin(phase)
            switch phase {
            case .records: try eraseRecords(in: database)
            case .files: try eraseFiles()
            }
        }
        try journal.finish()
    }

    /// Delete every record, table by table, save, and check the tables are empty. Not
    /// `ModelContainer.deleteAllData()`: it detaches the store from the container, so the next fetch
    /// or insert on it crashes (the app would crash on reseeding, and this check couldn't run), and
    /// it reports no failure of its own. Per-model deletes throw, save and leave the store open.
    static func eraseRecords(in database: ModelContainer) throws {
        let context = database.mainContext
        try context.delete(model: TimerPreset.self)
        try context.delete(model: SeedMarker.self)
        try context.delete(model: Note.self)
#if canImport(Attachments)
        try context.delete(model: LibraryItem.self)
        try context.delete(model: NoteLibraryReference.self)
        try context.delete(model: PendingAttachmentDeletion.self)
#endif
        try context.save()
        var remaining = try context.fetchCount(FetchDescriptor<TimerPreset>()) + context.fetchCount(FetchDescriptor<SeedMarker>())
        remaining += try context.fetchCount(FetchDescriptor<Note>())
#if canImport(Attachments)
        remaining += try context.fetchCount(FetchDescriptor<LibraryItem>())
            + context.fetchCount(FetchDescriptor<NoteLibraryReference>())
            + context.fetchCount(FetchDescriptor<PendingAttachmentDeletion>())
#endif
        if remaining > 0 { throw EraseError.recordsRemain(remaining) }
    }

    /// Remove the attachment originals and caches; nothing without the Attachments module.
    static func eraseFiles() throws {
#if canImport(Attachments)
        try StarterAttachments.removeAllFiles()
#endif
    }

    enum EraseError: Error, CustomStringConvertible {
        case recordsRemain(Int)

        var description: String {
            switch self {
            case .recordsRemain(let count): "\(count) records are still in the database"
            }
        }
    }
#endif

    static var reset: LocalDataReset { reset(journal: .standard) }

    static func reset(journal: ResetJournal) -> LocalDataReset {
        var steps: [LocalDataReset.Step] = [
            .defaults(StarterDefaults.store),
            .secrets(in: KeychainStore()),
        ]
#if canImport(Onboarding)
        // After the defaults wipe: TipKit keeps its own store, and this marks it for a reset.
        steps.append(LocalDataReset.Step("tips") { ContextualTips.resetOnNextLaunch() })
#endif
#if canImport(Attachments)
        // Without a database (previews, a build without the module) the files simply go.
        steps.append(LocalDataReset.Step("attachments") { try StarterAttachments.removeAllFiles() })
#endif
        return LocalDataReset(steps)
    }
}
#endif
