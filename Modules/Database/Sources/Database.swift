import Foundation
import SwiftData

/// Opens, seeds and erases an app's SwiftData store. The app owns its models, versioned schemas
/// and migration plan; this module owns none of them, because a package can't know another app's
/// schema or decide its migrations (docs/research/database.md).
///
/// ```swift
/// let container = try Database.open(schema: Schema(versionedSchema: AppSchemaV1.self),
///                                   migrationPlan: AppMigrationPlan.self,
///                                   storage: .applicationSupport(named: "MyApp"))
/// ```
///
/// A failed open throws a `DatabaseOpenError` and leaves the files alone: deleting a store is the
/// person's decision (`DatabaseLoader.startOver()`), never an automatic recovery.
public enum Database {
    /// Opens the store, creating it on first launch and migrating it when the schema moved on.
    public static func open(schema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
                            storage: DatabaseStorage) throws(DatabaseOpenError) -> ModelContainer {
        let configuration = switch storage {
        case .persistent(let url): ModelConfiguration(schema: schema, url: url)
        case .memory: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        do {
            return try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: configuration)
        } catch {
            throw DatabaseOpenError(storage: storage, underlying: error)
        }
    }

    /// An in-memory container with `seed` run once, for previews and tests.
    @MainActor
    public static func preview(schema: Schema, seed: (ModelContext) throws -> Void = { _ in }) throws -> ModelContainer {
        let container = try open(schema: schema, storage: .memory)
        try seed(container.mainContext)
        try container.mainContext.save()
        return container
    }

    /// Inserts once per `key`: the first call runs `insert` and saves a `SeedMarker` with it in the
    /// same transaction, later calls find the marker and do nothing. Returns whether it inserted.
    /// Add `SeedMarker.self` to the app's schema. Don't use an empty table as the sign of a first
    /// launch; people delete everything on purpose.
    @discardableResult
    public static func seed(_ key: String, in context: ModelContext, insert: (ModelContext) throws -> Void) throws -> Bool {
        var descriptor = FetchDescriptor<SeedMarker>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        guard try context.fetchCount(descriptor) == 0 else { return false }
        try insert(context)
        context.insert(SeedMarker(key: key))
        try context.save()
        return true
    }

    /// Deletes every record in the container, keeping the schema. For an Erase Local Data step.
    public static func erase(_ container: ModelContainer) throws {
        try container.deleteAllData()
    }

    /// Removes a persistent store's files (and its `-wal` and `-shm` sidecars) so the next open
    /// starts empty. Only for a store nothing has open.
    public static func removeStoreFiles(for storage: DatabaseStorage) throws {
        guard let url = storage.url else { return }
        let manager = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm"] where manager.fileExists(atPath: path) {
            try manager.removeItem(atPath: path)
        }
    }
}
