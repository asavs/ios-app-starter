import Foundation
import Observation
import SwiftData

/// Opens the app's store at launch and holds the outcome, so the root view can show the app on
/// success and `DatabaseRecoveryView` on failure. Retrying reopens the same files; starting over
/// removes them first, and only when the person asks.
@MainActor
@Observable
public final class DatabaseLoader {
    public enum Status {
        case ready(ModelContainer)
        case failed(DatabaseOpenError)
    }

    public private(set) var status: Status
    private let schema: Schema
    private let migrationPlan: (any SchemaMigrationPlan.Type)?
    public let storage: DatabaseStorage

    public init(schema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)? = nil, storage: DatabaseStorage) {
        self.schema = schema
        self.migrationPlan = migrationPlan
        self.storage = storage
        status = Self.open(schema: schema, migrationPlan: migrationPlan, storage: storage)
    }

    public var container: ModelContainer? {
        if case .ready(let container) = status { return container }
        return nil
    }

    /// Opens the same files again, for a failure that may have passed (a full disk, a lock).
    public func retry() {
        status = Self.open(schema: schema, migrationPlan: migrationPlan, storage: storage)
    }

    /// Removes the store's files and opens a fresh one. Data in the old files is gone.
    public func startOver() throws {
        try Database.removeStoreFiles(for: storage)
        retry()
    }

    private static func open(schema: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, storage: DatabaseStorage) -> Status {
        do {
            return .ready(try Database.open(schema: schema, migrationPlan: migrationPlan, storage: storage))
        } catch {
            return .failed(error)
        }
    }
}
