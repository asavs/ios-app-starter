import Foundation
#if canImport(Settings)
import Settings
#if canImport(Onboarding)
import Onboarding
#endif

/// Everything the template keeps on the device, for the Erase Local Data row. A module that adds a
/// store adds a step here; the database module's container is the next one.
enum StarterLocalData {
    static var reset: LocalDataReset {
        var steps: [LocalDataReset.Step] = [
            .defaults(),
            .secrets(in: KeychainStore()),
        ]
#if canImport(Onboarding)
        // After the defaults wipe: TipKit keeps its own store, and this marks it for a reset.
        steps.append(LocalDataReset.Step("tips") { ContextualTips.resetOnNextLaunch() })
#endif
        return LocalDataReset(steps)
    }
}
#endif
