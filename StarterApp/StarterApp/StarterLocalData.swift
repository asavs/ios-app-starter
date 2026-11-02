import Foundation
#if canImport(Settings)
import Settings
#if canImport(Onboarding)
import Onboarding
#endif
#if canImport(Database)
import Database
import SwiftData
#endif

/// Everything the template keeps on the device, for the Erase Local Data row. A module that adds a
/// store adds a step here. Main actor, like the Settings view that asks for it and the defaults it reads.
@MainActor
enum StarterLocalData {
#if canImport(Database)
    /// - Parameter database: The open container; its records go too. Seeded sample content comes
    ///   back on the next launch, as on a fresh install.
    static func reset(database: ModelContainer?) -> LocalDataReset {
        var reset = reset
        if let database {
            reset.steps.append(LocalDataReset.Step("database") { try Database.erase(database) })
        }
        return reset
    }
#endif

    static var reset: LocalDataReset {
        var steps: [LocalDataReset.Step] = [
            .defaults(StarterDefaults.store),
            .secrets(in: KeychainStore()),
        ]
#if canImport(Onboarding)
        // After the defaults wipe: TipKit keeps its own store, and this marks it for a reset.
        steps.append(LocalDataReset.Step("tips") { ContextualTips.resetOnNextLaunch() })
#endif
#if canImport(Attachments)
        steps.append(StarterAttachments.resetStep)
#endif
        return LocalDataReset(steps)
    }
}
#endif
