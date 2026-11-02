import Foundation

/// The defaults the app reads and writes: `.standard`, or under a UI-test launch a suite of the
/// test's own, so a test never reads or changes what a normal launch stored on the same simulator
/// or phone, and a `resets` launch starts from a fresh install. Every module takes `defaults:`;
/// views bind to the same suite through `defaultAppStorage` at the app's root. Main actor, like the
/// views and models that read it: `UserDefaults` isn't `Sendable`.
@MainActor
enum StarterDefaults {
    static let store = store(for: UITestLaunch.current)

    static func store(for launch: UITestLaunch?) -> UserDefaults {
        guard let launch, let suite = UserDefaults(suiteName: UITestLaunch.suiteName) else { return .standard }
        if launch.resets { suite.removePersistentDomain(forName: UITestLaunch.suiteName) }
        return suite
    }
}
