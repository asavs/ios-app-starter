import Foundation
#if canImport(Database)
import Database
import SwiftData

/// The template's store: its versioned schema, migration plan, location and seed. An app keeps
/// this file and replaces the models; the Database module opens whatever schema it's given.
enum StarterDatabase {
    static let schema = Schema(versionedSchema: StarterSchemaCurrent.self)

    /// The app's store, or under a UI-test launch one that never touches it: in memory, or a named
    /// store under the launch's directory for a test that relaunches into the same records, emptied
    /// first on a `resets` launch (`UITestLaunch`).
    static func storage(for launch: UITestLaunch? = .current) -> DatabaseStorage {
        guard let launch else { return .applicationSupport(named: "StarterApp") }
        guard let name = launch.store else { return .memory }
        let directory = UITestLaunch.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storage = DatabaseStorage.persistent(directory.appending(path: "\(name).store"))
        if launch.resets { try? Database.removeStoreFiles(for: storage) }
        return storage
    }

    @MainActor
    static func loader() -> DatabaseLoader {
        DatabaseLoader(schema: schema, migrationPlan: StarterMigrationPlan.self, storage: storage())
    }

    /// Two presets people can try, inserted once; deleting them doesn't bring them back.
    static func seedIfNeeded(in context: ModelContext) throws {
        try Database.seed("presets.v1", in: context) { context in
            context.insert(TimerPreset(name: "Tabata", plan: "intervals", work: 20, rest: 10, rounds: 8))
            context.insert(TimerPreset(name: "Pomodoro", plan: "focus", work: 25 * 60, rest: 5 * 60, rounds: 4))
        }
    }
}
#endif
