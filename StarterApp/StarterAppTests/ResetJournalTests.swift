import Foundation
import SwiftData
import Testing
@testable import StarterApp
#if canImport(Database) && canImport(Settings)
import Database

/// Erase Local Data as a journaled, resumable operation: records before files, each phase recorded
/// before it runs, and an unfinished erase completed on the next launch before anything seeds.
@MainActor
struct ResetJournalTests {
    private let directory = URL.temporaryDirectory.appending(path: "ResetJournalTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private var journal: ResetJournal { ResetJournal(url: directory.appending(path: "erase-in-progress.json")) }

    private func cleanUp() { try? FileManager.default.removeItem(at: directory) }

    @Test func theJournalRecordsThePhaseAndTheOwedPhasesFollowFromIt() throws {
        defer { cleanUp() }
        #expect(journal.pending == nil && journal.owedPhases.isEmpty)
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        try journal.begin(.records, at: started)
        #expect(journal.pending == ResetJournal.Entry(startedAt: started, phase: .records))
        #expect(journal.owedPhases == [.records, .files], "From the phase it was in to the end")
        try journal.begin(.files, at: started.addingTimeInterval(5))
        #expect(journal.pending?.startedAt == started, "The start of the erase is kept across phases")
        #expect(journal.owedPhases == [.files])
        try journal.finish()
        #expect(journal.pending == nil)
        try journal.finish() // Finishing twice is harmless.
    }

    @Test func anEraseEmptiesTheRecordsBeforeTheFilesAndClosesTheJournal() throws {
        defer { cleanUp() }
        let container = try Database.preview(schema: StarterDatabase.schema) { context in
            context.insert(TimerPreset(name: "Tabata", plan: "intervals", work: 20, rest: 10, rounds: 8))
            context.insert(Note(title: "Plan", body: "Three rounds."))
            context.insert(SeedMarker(key: "presets.v1"))
        }
        let reset = StarterLocalData.reset(database: container, journal: journal)
        #expect(reset.steps.map(\.name).suffix(2) == ["database", "attachments"], "Records go before files")
        try reset.erase()
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TimerPreset>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Note>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SeedMarker>()) == 0, "The marker goes too: the next launch seeds again, as on a fresh install")
        #expect(journal.pending == nil, "A finished erase leaves no journal")
    }

    @Test func anUnfinishedEraseIsCompletedOnTheNextLaunchBeforeSeeding() throws {
        defer { cleanUp() }
        let container = try Database.preview(schema: StarterDatabase.schema) { context in
            context.insert(TimerPreset(name: "Leftover", plan: "intervals", work: 20, rest: 10, rounds: 8))
            context.insert(SeedMarker(key: "presets.v1"))
        }
        // The last run got as far as recording the records phase and died.
        try journal.begin(.records)
        try StarterLocalData.recoverUnfinishedErase(database: container, journal: journal)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TimerPreset>()) == 0, "The owed phases ran")
        #expect(journal.pending == nil, "And the journal closed")
        try StarterDatabase.seedIfNeeded(in: container.mainContext)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TimerPreset>()) == 2, "Seeding runs afterwards, as on a fresh install")

        // Nothing owed: recovery is a no-op and leaves the records alone.
        try StarterLocalData.recoverUnfinishedErase(database: container, journal: journal)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<TimerPreset>()) == 2)
    }

    @Test func aRecordThatSurvivesTheEraseIsReportedAndKeepsTheJournal() throws {
        defer { cleanUp() }
        // A container whose erase can't be verified empty: the check is what reports it.
        let container = try Database.preview(schema: StarterDatabase.schema)
        try StarterLocalData.eraseRecords(in: container) // Empty already: passes.
        #expect(String(describing: StarterLocalData.EraseError.recordsRemain(3)) == "3 records are still in the database")
    }
}
#endif
