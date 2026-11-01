import Foundation
#if canImport(Database)
import Database
import SwiftData

/// The template's store: its versioned schema, migration plan, location and seed. An app keeps
/// this file and replaces the models; the Database module opens whatever schema it's given.
enum StarterDatabase {
    static let schema = Schema(versionedSchema: StarterSchemaV1.self)

    /// `-database.store <name>` puts the store in the temporary directory under that name, and
    /// `-database.reset` removes it before opening, so UI tests start clean and can relaunch into
    /// the same data.
    static func storage(arguments: [String] = CommandLine.arguments) -> DatabaseStorage {
        guard let index = arguments.firstIndex(of: "-database.store"), index + 1 < arguments.count else {
            return .applicationSupport(named: "StarterApp")
        }
        let storage = DatabaseStorage.persistent(URL.temporaryDirectory.appending(path: "\(arguments[index + 1]).store"))
        if arguments.contains("-database.reset") { try? Database.removeStoreFiles(for: storage) }
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
