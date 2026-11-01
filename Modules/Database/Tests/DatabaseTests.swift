import Foundation
import SwiftData
import Testing
@testable import Database

/// A model only these tests know; the module itself has no schema of its own.
@Model
final class Note {
    var text: String
    init(text: String) { self.text = text }
}

enum NotesSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Note.self, SeedMarker.self] }
}

enum NotesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NotesSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

@MainActor
struct DatabaseTests {
    private let schema = Schema(versionedSchema: NotesSchemaV1.self)

    private func temporaryStore() -> DatabaseStorage {
        .persistent(URL.temporaryDirectory.appending(path: "DatabaseTests-\(UUID().uuidString).store"))
    }

    private func count(in container: ModelContainer) throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<Note>())
    }

    @Test func memoryContainerHoldsRecordsForItsLifetime() throws {
        let container = try Database.open(schema: schema, migrationPlan: NotesMigrationPlan.self, storage: .memory)
        container.mainContext.insert(Note(text: "one"))
        try container.mainContext.save()
        #expect(try count(in: container) == 1)
        let another = try Database.open(schema: schema, storage: .memory)
        #expect(try count(in: another) == 0, "Each in-memory container starts empty")
    }

    @Test func persistentStoreSurvivesReopening() throws {
        let storage = temporaryStore()
        defer { try? Database.removeStoreFiles(for: storage) }
        do {
            let container = try Database.open(schema: schema, migrationPlan: NotesMigrationPlan.self, storage: storage)
            container.mainContext.insert(Note(text: "kept"))
            try container.mainContext.save()
        }
        let reopened = try Database.open(schema: schema, migrationPlan: NotesMigrationPlan.self, storage: storage)
        #expect(try count(in: reopened) == 1)
    }

    @Test func openingACorruptFileFailsWithoutTouchingIt() throws {
        let storage = temporaryStore()
        defer { try? Database.removeStoreFiles(for: storage) }
        let url = try #require(storage.url)
        let junk = Data("not a database".utf8)
        try junk.write(to: url)
        let error = #expect(throws: DatabaseOpenError.self) { try Database.open(schema: schema, storage: storage) }
        #expect(error?.storage == storage)
        #expect(error?.description.hasPrefix("Couldn't open the store") == true)
        #expect(try Data(contentsOf: url) == junk, "A failed open leaves the file as it was")
    }

    @Test func openErrorNamesTheFileNotItsContents() {
        struct Underlying: Error {}
        let error = DatabaseOpenError(storage: .persistent(URL(filePath: "/tmp/private-notes.store")), underlying: Underlying())
        #expect(error.description.hasPrefix("Couldn't open the store private-notes.store:"))
        #expect(DatabaseOpenError(storage: .memory, underlying: Underlying()).description.hasPrefix("Couldn't open the in-memory store"))
    }

    @Test func seedingRunsOncePerKeyEvenAfterTheRecordsAreDeleted() throws {
        let container = try Database.open(schema: schema, storage: .memory)
        let context = container.mainContext
        #expect(try Database.seed("notes.v1", in: context) { $0.insert(Note(text: "seeded")) })
        #expect(try count(in: container) == 1)
        #expect(try Database.seed("notes.v1", in: context) { $0.insert(Note(text: "again")) } == false)
        try context.delete(model: Note.self)
        try context.save()
        #expect(try Database.seed("notes.v1", in: context) { $0.insert(Note(text: "again")) } == false,
                "An empty table isn't a first launch")
        #expect(try Database.seed("notes.v2", in: context) { $0.insert(Note(text: "v2")) }, "A new key seeds")
        #expect(try count(in: container) == 1)
    }

    @Test func aFailedSeedLeavesNoMarker() throws {
        struct Refused: Error {}
        let container = try Database.open(schema: schema, storage: .memory)
        let context = container.mainContext
        #expect(throws: Refused.self) {
            try Database.seed("notes.v1", in: context) { _ in throw Refused() }
        }
        #expect(try context.fetchCount(FetchDescriptor<SeedMarker>()) == 0)
        #expect(try Database.seed("notes.v1", in: context) { $0.insert(Note(text: "retry")) }, "The retry seeds")
    }

    @Test func previewSeedsOnceInMemory() throws {
        let container = try Database.preview(schema: schema) { $0.insert(Note(text: "preview")) }
        #expect(try count(in: container) == 1)
    }

    @Test func eraseDeletesEveryRecord() throws {
        let container = try Database.open(schema: schema, storage: .memory)
        container.mainContext.insert(Note(text: "gone"))
        container.mainContext.insert(SeedMarker(key: "notes.v1"))
        try container.mainContext.save()
        try Database.erase(container)
        #expect(try count(in: container) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<SeedMarker>()) == 0)
    }

    @Test func removingStoreFilesTakesTheSidecars() throws {
        let storage = temporaryStore()
        let url = try #require(storage.url)
        for suffix in ["", "-wal", "-shm"] { try Data().write(to: URL(filePath: url.path + suffix)) }
        try Database.removeStoreFiles(for: storage)
        for suffix in ["", "-wal", "-shm"] { #expect(FileManager.default.fileExists(atPath: url.path + suffix) == false) }
        try Database.removeStoreFiles(for: storage) // Nothing to remove is fine.
        try Database.removeStoreFiles(for: .memory)
    }

    @Test func loaderReportsFailureAndStartsOverOnlyWhenAsked() throws {
        let storage = temporaryStore()
        defer { try? Database.removeStoreFiles(for: storage) }
        let url = try #require(storage.url)
        try Data("not a database".utf8).write(to: url)
        let loader = DatabaseLoader(schema: schema, migrationPlan: NotesMigrationPlan.self, storage: storage)
        guard case .failed = loader.status else { Issue.record("A corrupt file should fail to open"); return }
        #expect(loader.container == nil)
        loader.retry()
        guard case .failed = loader.status else { Issue.record("Retrying the same file fails the same way"); return }
        #expect(try Data(contentsOf: url) == Data("not a database".utf8), "Failing leaves the file alone")
        try loader.startOver()
        guard case .ready(let container) = loader.status else { Issue.record("Starting over opens a fresh store"); return }
        #expect(try count(in: container) == 0)
    }

    @Test func loaderOpensAHealthyStore() throws {
        let loader = DatabaseLoader(schema: schema, storage: .memory)
        #expect(loader.container != nil)
        #expect(loader.storage == .memory)
    }

    @Test func viewsConstructWithPublicInitializers() throws {
        let loader = DatabaseLoader(schema: schema, storage: .memory)
        _ = DatabaseGate(loader) { Text("App") }
        struct Underlying: Error {}
        _ = DatabaseRecoveryView(loader: loader, error: DatabaseOpenError(storage: .memory, underlying: Underlying()))
    }
}

import SwiftUI
