import Foundation
import Testing
@testable import StarterApp
#if canImport(Database)
import Database
#endif
#if canImport(Attachments)
import Attachments
#endif

/// The UI-test launch contract as the app reads it: a scenario's arguments come back as the same
/// scenario, a normal launch reads nothing, and only a reset launch empties the test suite.
struct UITestLaunchTests {
    @Test func argumentsRoundTrip() throws {
        let scenario = UITestLaunch(tab: Identifiers.Tabs.timer, store: "presets")
        let read = try #require(UITestLaunch(arguments: scenario.arguments))
        #expect(read.tab == Identifiers.Tabs.timer)
        #expect(read.store == "presets")
        #expect(read.resets)

        let again = try #require(UITestLaunch(arguments: scenario.relaunch.arguments))
        #expect(again.store == "presets")
        #expect(!again.resets, "A relaunch keeps the data")
        #expect(!scenario.relaunch.arguments.contains("-database.reset"))
    }

    @Test func everyFlagCarriesAValue() {
        let arguments = UITestLaunch(tab: Identifiers.Tabs.welcome, store: "x", extra: ["-attachments.fakeCamera", "YES"]).arguments
        for (index, argument) in arguments.enumerated() where argument.hasPrefix("-") {
            #expect(index + 1 < arguments.count && !arguments[index + 1].hasPrefix("-"),
                    "\(argument) should be followed by its value, so the argument domain reads pairs")
        }
    }

    @Test func onboardingAndTipsArePinnedThroughTheArgumentDomain() {
        let shows = UITestLaunch(onboarding: .shows).arguments
        #expect(shows.contains("-onboarding.completedVersion") && shows[shows.firstIndex(of: "-onboarding.completedVersion")! + 1] == "0")
        #expect(shows.contains("-tips.testing"))
        let stored = UITestLaunch(onboarding: .asStored, tips: .fresh).arguments
        #expect(!stored.contains("-onboarding.completedVersion"), "Nothing pinned: the stored record decides")
        #expect(stored.contains("-tips.reset") && !stored.contains("-tips.testing"))
    }

    @Test func aNormalLaunchReadsNothing() {
        #expect(UITestLaunch(arguments: []) == nil)
        #expect(UITestLaunch(arguments: ["-tabs.selected", "timer"]) == nil)
        #expect(UITestLaunch(arguments: [UITestLaunch.resetFlag, "YES"]) == nil,
                "A reset request without the flag is not a test launch")
    }

    @Test @MainActor func defaultsAreStandardOnANormalLaunch() {
        #expect(StarterDefaults.store(for: nil) === UserDefaults.standard)
    }

    @Test @MainActor func onlyAResetLaunchEmptiesTheSuite() throws {
        let suite = try #require(UserDefaults(suiteName: UITestLaunch.suiteName))
        defer { suite.removePersistentDomain(forName: UITestLaunch.suiteName) }
        suite.set("kept", forKey: "sentinel")

        let relaunch = StarterDefaults.store(for: UITestLaunch(resets: false))
        #expect(relaunch !== UserDefaults.standard)
        #expect(relaunch.string(forKey: "sentinel") == "kept", "A relaunch keeps the suite")

        let reset = StarterDefaults.store(for: UITestLaunch())
        #expect(reset.string(forKey: "sentinel") == nil, "A reset launch empties it")
    }

#if canImport(Database)
    @Test func databaseStaysOutOfTheAppsStoreUnderATestLaunch() {
        #expect(StarterDatabase.storage(for: nil) == .applicationSupport(named: "StarterApp"))
        #expect(StarterDatabase.storage(for: UITestLaunch()) == .memory)
        let named = StarterDatabase.storage(for: UITestLaunch(store: "presets", resets: false))
        #expect(named == .persistent(UITestLaunch.directory.appending(path: "presets.store")))
    }
#endif

#if canImport(Attachments)
    @Test func attachmentsMoveUnderTheLaunchDirectory() {
        let store = StarterAttachments.store(for: UITestLaunch(resets: false), overrides: AttachmentTestOverrides())
        #expect(store.root.path().hasPrefix(UITestLaunch.directory.path()))
        let own = URL(filePath: NSTemporaryDirectory()).appending(path: "own")
        let explicit = StarterAttachments.store(for: UITestLaunch(resets: false), overrides: AttachmentTestOverrides(root: own))
        #expect(explicit.root.path().hasPrefix(own.path()), "A test that names a root keeps it")
        #expect(StarterAttachments.store(for: nil, overrides: AttachmentTestOverrides()).root == AttachmentStore.standard().root)
    }
#endif
}
