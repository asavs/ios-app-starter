import Foundation
#if canImport(Database)
import Database
import SwiftData
#if canImport(Attachments)
import Attachments
#endif

// Two store histories live here, one per build (docs/research/content-ownership.md):
//
// - Database with Attachments: V1 -> V2 (presets gain attachments) -> V3 (Library, Notes, references,
//   pending deletions). A store written by any of them opens and migrates forward.
// - Database without Attachments: V1 -> Text2 (Notes). It compiles without the Attachments module.
//
// A store from one history opened by the other build is an unsupported configuration: the open fails
// and `DatabaseGate` shows recovery with the files kept, never a silent new store. Shipped versions
// are frozen: their models, `Attachment`'s encoding and `SeedMarker`'s shape stay as they were.

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
/// Version 2, frozen: attachments on a preset (a photo of the drill, a PDF of the plan) as
/// `Attachment` values, whose files the Attachments store keeps. Adding a defaulted attribute is a
/// lightweight migration; `StarterMigrationPlan` lists the stage.
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

/// Version 3: the Library and Notes. `TimerPreset` is V2's, unchanged. The new tables start empty;
/// nothing moves a preset's attachments into the Library. References between notes and items are
/// app-level UUIDs, not SwiftData relationships, so deleting a note or an item never cascades into
/// the other (docs/research/content-ownership.md, "Record ownership and deletion").
enum StarterSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [TimerPreset.self, SeedMarker.self, LibraryItem.self, Note.self, NoteLibraryReference.self, PendingAttachmentDeletion.self]
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

    /// A collected photo, file or link: the owner of its one `Attachment` and the files behind it.
    /// `id` is the stable identity notes refer to; a title can change without breaking a link.
    @Model
    final class LibraryItem {
        @Attribute(.unique) var id: UUID
        var title: String
        var createdAt: Date
        var modifiedAt: Date
        var attachment: Attachment

        init(id: UUID = UUID(), title: String, attachment: Attachment, createdAt: Date = .now, modifiedAt: Date = .now) {
            self.id = id
            self.title = title
            self.attachment = attachment
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
        }
    }

    /// Authored text. Attachments are never owned here: a note refers to Library items.
    @Model
    final class Note {
        @Attribute(.unique) var id: UUID
        var title: String
        var body: String
        var createdAt: Date
        var modifiedAt: Date

        init(id: UUID = UUID(), title: String, body: String, createdAt: Date = .now, modifiedAt: Date = .now) {
            self.id = id
            self.title = title
            self.body = body
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
        }
    }

    /// A non-owning link from a note to a Library item, one per pair, ordered within the note.
    /// Removing it leaves the item; deleting the item removes it and keeps the note's text.
    @Model
    final class NoteLibraryReference {
        @Attribute(.unique) var id: UUID
        var noteID: UUID
        var itemID: UUID
        var order: Int

        init(id: UUID = UUID(), noteID: UUID, itemID: UUID, order: Int) {
            self.id = id
            self.noteID = noteID
            self.itemID = itemID
            self.order = order
        }
    }

    /// Cleanup intent, saved in the same transaction as the record change that released the last
    /// owner of an attachment, so a crash between the save and the file removal is retried on the
    /// next launch instead of leaving the files behind. Carries everything `AttachmentStore.remove`
    /// needs; it is not an owner.
    @Model
    final class PendingAttachmentDeletion {
        @Attribute(.unique) var id: UUID
        var attachment: Attachment
        var requestedAt: Date
        var attempts: Int
        var lastError: String?

        init(attachment: Attachment, requestedAt: Date = .now) {
            id = attachment.id
            self.attachment = attachment
            self.requestedAt = requestedAt
            attempts = 0
        }
    }
}

/// A saved timer plan: which plan, its times and its attachments. `plan` is the `TimerPlan` raw
/// value kept as text so the store doesn't depend on the timer modules being enabled.
typealias TimerPreset = StarterSchemaV3.TimerPreset
typealias LibraryItem = StarterSchemaV3.LibraryItem
typealias Note = StarterSchemaV3.Note
typealias NoteLibraryReference = StarterSchemaV3.NoteLibraryReference
typealias PendingAttachmentDeletion = StarterSchemaV3.PendingAttachmentDeletion
typealias StarterSchemaCurrent = StarterSchemaV3

enum StarterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StarterSchemaV1.self, StarterSchemaV2.self, StarterSchemaV3.self] }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: StarterSchemaV1.self, toVersion: StarterSchemaV2.self),
            // New tables only; every existing row keeps its values (StoreFixtureMigrationTests).
            .lightweight(fromVersion: StarterSchemaV2.self, toVersion: StarterSchemaV3.self),
        ]
    }
}
#else
/// The text-only successor to V1 for a build without the Attachments module: Notes beside the
/// presets. Its identity differs from the media history's V2 and V3 on purpose; a store from one
/// history isn't a lightweight step away from the other.
enum StarterSchemaText2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 1, 0) }

    static var models: [any PersistentModel.Type] {
        [TimerPreset.self, SeedMarker.self, Note.self]
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

    /// Authored text; the same shape as the media history's `Note`.
    @Model
    final class Note {
        @Attribute(.unique) var id: UUID
        var title: String
        var body: String
        var createdAt: Date
        var modifiedAt: Date

        init(id: UUID = UUID(), title: String, body: String, createdAt: Date = .now, modifiedAt: Date = .now) {
            self.id = id
            self.title = title
            self.body = body
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
        }
    }
}

/// A saved timer plan: which plan and its times.
typealias TimerPreset = StarterSchemaText2.TimerPreset
typealias Note = StarterSchemaText2.Note
typealias StarterSchemaCurrent = StarterSchemaText2

enum StarterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StarterSchemaV1.self, StarterSchemaText2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: StarterSchemaV1.self, toVersion: StarterSchemaText2.self)]
    }
}
#endif
#endif
