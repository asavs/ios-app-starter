import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import StarterApp
#if canImport(Database)
import Database
#endif
#if canImport(Attachments)
import Attachments
#endif

#if canImport(Database)
/// `Fixtures/` beside this file, in the source tree.
private let fixturesDirectory = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures", directoryHint: .isDirectory)
private var fixturesAreReachable: Bool { FileManager.default.fileExists(atPath: fixturesDirectory.path()) }

/// The authentic stores under `Fixtures/` (written by the apps that shipped schema V1 and V2, see
/// their manifests) open under the current schema with every row intact. Each test works on a copy;
/// the fixture itself is checked against its recorded hashes afterwards.
///
/// The fixtures are read from the source tree beside this file, so the tests run on the simulator
/// (locally and on the hosted runner) and are skipped on a phone, which can't see the Mac's files.
@MainActor
@Suite(.enabled(if: fixturesAreReachable, "The Fixtures folder is only reachable from a Mac simulator run"))
struct StoreFixtureMigrationTests {
    private func fixtureRoot(_ fixture: String) throws -> URL {
        let root = fixturesDirectory.appending(path: fixture, directoryHint: .isDirectory)
        try #require(FileManager.default.fileExists(atPath: root.path()), "Fixtures/\(fixture) should exist beside the tests")
        return root
    }

    /// A fresh copy of a fixture's store, with its sidecars, under a directory of this test's own.
    private func copy(_ fixture: String, store name: String) throws -> (storage: DatabaseStorage, directory: URL) {
        let source = try fixtureRoot(fixture)
        let directory = URL.temporaryDirectory.appending(path: "StoreFixtureMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let file = source.appending(path: "store/\(name)\(suffix)")
            if FileManager.default.fileExists(atPath: file.path()) {
                try FileManager.default.copyItem(at: file, to: directory.appending(path: "\(name)\(suffix)"))
            }
        }
        return (.persistent(directory.appending(path: name)), directory)
    }

    /// The fixture's files still match `SHA256SUMS`: nothing opened the original.
    private func fixtureIsUntouched(_ fixture: String) throws -> Bool {
        let root = try fixtureRoot(fixture)
        let sums = try String(contentsOf: root.appending(path: "SHA256SUMS"), encoding: .utf8)
        for line in sums.split(separator: "\n") {
            let parts = line.split(separator: "  ", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let path = parts[1].replacingOccurrences(of: "./", with: "")
            let data = try Data(contentsOf: root.appending(path: path))
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == String(parts[0]) else { return false }
        }
        return true
    }

    private func presets(in container: ModelContainer) throws -> [TimerPreset] {
        try container.mainContext.fetch(FetchDescriptor<TimerPreset>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func markers(in container: ModelContainer) throws -> [SeedMarker] {
        try container.mainContext.fetch(FetchDescriptor<SeedMarker>())
    }

    @Test func theVersionOneStoreOpensUnderTheCurrentSchemaWithItsRowsIntact() throws {
        let (storage, directory) = try copy("StoreV1", store: "fixture-v1.store")
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self, storage: storage)
        let presets = try self.presets(in: container)
        #expect(presets.map(\.name) == ["Tabata", "Mine"], "The seeded Tabata and the saved Mine; the deleted Pomodoro stays deleted")
        #expect(presets.map { "\($0.plan) \($0.work)/\($0.rest) x\($0.rounds)" } == ["intervals 20/10 x8", "intervals 20/10 x8"])
        #expect(presets.allSatisfy { $0.createdAt.timeIntervalSinceReferenceDate > 815_000_000 })
        let markers = try self.markers(in: container)
        #expect(markers.map(\.key) == ["presets.v1"], "The seed marker survives, so seeding won't run again")
        try StarterDatabase.seedIfNeeded(in: container.mainContext) // Finds the marker and does nothing.
        #expect(try self.presets(in: container).count == 2, "Seeding doesn't bring the deleted Pomodoro back")
        #expect(try self.markers(in: container).count == 1)
#if canImport(Attachments)
        #expect(presets.allSatisfy { $0.attachments.isEmpty }, "V1 rows gain an empty attachment list")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<LibraryItem>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<NoteLibraryReference>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PendingAttachmentDeletion>()) == 0)
#endif
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Note>()) == 0, "New tables start empty")
        #expect(try fixtureIsUntouched("StoreV1"))
    }

#if canImport(Attachments)
    @Test func theVersionTwoStoreOpensUnderTheCurrentSchemaWithAttachmentsAndFilesIntact() throws {
        let (storage, directory) = try copy("StoreV2", store: "fixture-v2.store")
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self, storage: storage)
        let presets = try self.presets(in: container)
        #expect(presets.map(\.name) == ["Tabata", "Mine"])
        let tabata = try #require(presets.first)
        #expect(tabata.attachments.count == 2, "A photo and a link")
        let photo = try #require(tabata.attachments.first { $0.kind == .image })
        #expect(photo.id == UUID(uuidString: "26CC7C46-A043-499A-97BF-E81C36E91D93"))
        #expect(photo.relativePath == "26CC7C46-A043-499A-97BF-E81C36E91D93.jpeg")
        #expect(photo.contentType == "public.jpeg" && photo.byteCount == 7455 && photo.displayName == "Capture")
        let link = try #require(tabata.attachments.first { $0.kind == .link })
        #expect(link.url == URL(string: "https://www.example.com/plan") && link.displayName == "Plan page")
        #expect(try #require(presets.last).attachments.isEmpty, "An empty attachment array decodes as empty")
        #expect(try self.markers(in: container).map(\.key) == ["presets.v1"])
        try StarterDatabase.seedIfNeeded(in: container.mainContext)
        #expect(try self.presets(in: container).count == 2, "Seeding doesn't run again")

        // The original bytes the store refers to are in the fixture's attachments root, unchanged.
        let root = try fixtureRoot("StoreV2")
        let original = root.appending(path: "attachments/Originals/\(photo.relativePath ?? "")")
        let bytes = try Data(contentsOf: original)
        #expect(bytes.count == Int(photo.byteCount), "The store's byte count matches the file")
        #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                == "f2d2ecb8ef314f525a9ea1639b1ebc22c03b4770af32640908975ae92dda0afc")

        #expect(try container.mainContext.fetchCount(FetchDescriptor<LibraryItem>()) == 0)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Note>()) == 0)
        #expect(try fixtureIsUntouched("StoreV2"))
    }

    @Test func aMigratedStoreReopensAndTakesNewContent() throws {
        let (storage, directory) = try copy("StoreV2", store: "fixture-v2.store")
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let first = try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self, storage: storage)
            let note = Note(title: "Plan notes", body: "Three rounds, then stretch.")
            first.mainContext.insert(note)
            let item = LibraryItem(title: "Plan page", attachment: try #require(self.presets(in: first).first?.attachments.last))
            first.mainContext.insert(item)
            first.mainContext.insert(NoteLibraryReference(noteID: note.id, itemID: item.id, order: 0))
            try first.mainContext.save()
        }
        // A second open of the same files: a relaunch.
        let second = try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self, storage: storage)
        #expect(try self.presets(in: second).map(\.name) == ["Tabata", "Mine"], "The presets are still there")
        let notes = try second.mainContext.fetch(FetchDescriptor<Note>())
        #expect(notes.map(\.title) == ["Plan notes"])
        let references = try second.mainContext.fetch(FetchDescriptor<NoteLibraryReference>())
        #expect(references.count == 1 && references.first?.noteID == notes.first?.id)
        let items = try second.mainContext.fetch(FetchDescriptor<LibraryItem>())
        #expect(items.first?.attachment.kind == .link, "A collected item keeps the attachment value as it was")
        try StarterDatabase.seedIfNeeded(in: second.mainContext)
        #expect(try self.presets(in: second).count == 2, "Seeding never runs again on a migrated store")
    }
#else
    @Test func aMediaStoreIsAnUnsupportedConfigurationForTheTextBuild() throws {
        let (storage, directory) = try copy("StoreV2", store: "fixture-v2.store")
        defer { try? FileManager.default.removeItem(at: directory) }
        // The V2 store's TimerPreset has an attachments column this history never declared; the open
        // must fail and leave the files for a compatible build, not silently open a new store.
        #expect(throws: DatabaseOpenError.self) {
            try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self, storage: storage)
        }
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "fixture-v2.store").path()), "The files stay")
    }
#endif

    @Test func theSyntheticVersionOneUpgradeStillHolds() throws {
        // The older test's path: a V1 store written by today's frozen type, then opened current.
        let url = URL.temporaryDirectory.appending(path: "StoreFixtureMigrationTests-synthetic-\(UUID().uuidString).store")
        let storage = DatabaseStorage.persistent(url)
        defer { try? Database.removeStoreFiles(for: storage) }
        do {
            let v1 = try Database.open(schema: Schema(versionedSchema: StarterSchemaV1.self), migrationPlan: nil, storage: storage)
            v1.mainContext.insert(StarterSchemaV1.TimerPreset(name: "Old", plan: "intervals", work: 30, rest: 15, rounds: 2))
            v1.mainContext.insert(SeedMarker(key: "presets.v1"))
            try v1.mainContext.save()
        }
        let current = try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self, storage: storage)
        #expect(try self.presets(in: current).map(\.name) == ["Old"])
        #expect(try self.markers(in: current).map(\.key) == ["presets.v1"])
    }
}
#endif
