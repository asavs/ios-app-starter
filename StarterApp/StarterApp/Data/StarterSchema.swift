import Foundation
#if canImport(Database)
import Database
import SwiftData

/// Version 1 of the store. Changing a model means adding a V2 here and a stage in
/// `StarterMigrationPlan`, never editing this in place: shipped schemas stay frozen so an old
/// store can still be read (docs/research/database.md).
enum StarterSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [TimerPreset.self, SeedMarker.self]
    }
}

enum StarterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StarterSchemaV1.self] }

    static var stages: [MigrationStage] { [] }
}
#endif
