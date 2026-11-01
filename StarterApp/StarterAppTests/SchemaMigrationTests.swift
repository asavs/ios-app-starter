#if canImport(Database) && canImport(Attachments)
import Attachments
import Database
import Foundation
import SwiftData
import Testing
@testable import StarterApp

/// A store written by the shipped V1 schema opens under the current plan and keeps its records.
@MainActor
struct SchemaMigrationTests {
    @Test func aVersionOneStoreMigratesToTheCurrentSchema() throws {
        let url = URL.temporaryDirectory.appending(path: "SchemaMigrationTests-\(UUID().uuidString).store")
        let storage = DatabaseStorage.persistent(url)
        defer { try? Database.removeStoreFiles(for: storage) }

        // What the V1 build wrote: no migration plan, V1 models only.
        do {
            let v1 = try Database.open(schema: Schema(versionedSchema: StarterSchemaV1.self), migrationPlan: nil, storage: storage)
            let context = ModelContext(v1)
            context.insert(StarterSchemaV1.TimerPreset(name: "Old", plan: "intervals", work: 30, rest: 15, rounds: 2))
            try context.save()
        }

        let current = try Database.open(schema: StarterDatabase.schema, migrationPlan: StarterMigrationPlan.self, storage: storage)
        let editing = ModelContext(current)
        let presets = try editing.fetch(FetchDescriptor<TimerPreset>())
        let old = try #require(presets.first { $0.name == "Old" })
        #expect(old.work == 30)
        #expect(old.attachments.isEmpty, "The added attribute starts at its default")

        let attachment = Attachments.Attachment(kind: .link, displayName: "Apple", contentType: "public.url",
                                                url: URL(string: "https://apple.com"))
        old.attachments.append(attachment)
        try editing.save()
        let reading = ModelContext(current)
        let saved = try #require(try reading.fetch(FetchDescriptor<TimerPreset>()).first { $0.name == "Old" })
        #expect(saved.attachments == [attachment], "Attachment values round-trip through the store")
    }
}
#endif
