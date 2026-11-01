import Foundation
#if canImport(Database)
import Database
import SwiftData
#if canImport(Attachments)
import Attachments
#endif

/// Version 1 of the store, frozen: a shipped schema stays as it was so an old store can still be
/// read and migrated (docs/research/database.md). Its models live inside it; the app's current
/// `TimerPreset` is the latest version's.
enum StarterSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [TimerPreset.self, SeedMarker.self]
    }

    @Model
    final class TimerPreset {
        var name: String
        var plan: String
        var work: Int
        var rest: Int
        var rounds: Int
        var createdAt: Date

        init(name: String, plan: String, work: Int, rest: Int, rounds: Int, createdAt: Date = .now) {
            self.name = name
            self.plan = plan
            self.work = work
            self.rest = rest
            self.rounds = rounds
            self.createdAt = createdAt
        }
    }
}

#if canImport(Attachments)
/// Version 2 adds attachments to a preset (a photo of the drill, a PDF of the plan): `Attachment`
/// values, whose files the Attachments store keeps. Adding a defaulted attribute is a lightweight
/// migration; `StarterMigrationPlan` lists the stage.
enum StarterSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [TimerPreset.self, SeedMarker.self]
    }

    @Model
    final class TimerPreset {
        var name: String
        var plan: String
        var work: Int
        var rest: Int
        var rounds: Int
        var createdAt: Date
        var attachments: [Attachment] = []

        init(name: String, plan: String, work: Int, rest: Int, rounds: Int, createdAt: Date = .now,
             attachments: [Attachment] = []) {
            self.name = name
            self.plan = plan
            self.work = work
            self.rest = rest
            self.rounds = rounds
            self.createdAt = createdAt
            self.attachments = attachments
        }
    }
}

/// A saved timer plan: which plan, its times and its attachments. `plan` is the `TimerPlan` raw
/// value kept as text so the store doesn't depend on the timer modules being enabled.
typealias TimerPreset = StarterSchemaV2.TimerPreset
typealias StarterSchemaCurrent = StarterSchemaV2

enum StarterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StarterSchemaV1.self, StarterSchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: StarterSchemaV1.self, toVersion: StarterSchemaV2.self)]
    }
}
#else
/// A saved timer plan: which plan and its times.
typealias TimerPreset = StarterSchemaV1.TimerPreset
typealias StarterSchemaCurrent = StarterSchemaV1

enum StarterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StarterSchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}
#endif
#endif
