import Foundation
import Testing
@testable import StarterApp

#if canImport(TabShell)
/// The registry and the chosen tabs: what a stored choice means in a given build, what stays
/// reachable, and what a deep link to a hidden or missing feature does.
@MainActor
struct FeatureChoicesTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() throws {
        suiteName = "FeatureChoicesTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    /// Every feature compiled in, and a build without the Timer modules.
    private let full = StarterFeature.all.map { feature in
        StarterFeature(id: feature.id, title: feature.title, summary: feature.summary, systemImage: feature.systemImage,
                       isAvailable: true, isDefault: feature.isDefault, isRequired: feature.isRequired)
    }
    private var withoutTimer: [StarterFeature] {
        full.map { feature in
            StarterFeature(id: feature.id, title: feature.title, summary: feature.summary, systemImage: feature.systemImage,
                           isAvailable: feature.id != .timer, isDefault: feature.isDefault, isRequired: feature.isRequired)
        }
    }

    @Test func everyTabHasAFeatureAndTheWelcomeTabReadsHome() {
        #expect(StarterFeature.all.map(\.id) == StarterTab.allCases, "The registry lists every tab, in default order")
        #expect(String(localized: StarterFeature.feature(.welcome).title) == "Home")
        #expect(StarterFeature.feature(.welcome).item.accessibilityIdentifier == "tabs.welcome", "The identity stays welcome")
        #expect(StarterFeature.feature(.settings).isRequired)
    }

    @Test func nothingStoredMeansTheDefaults() {
        #expect(FeatureChoices.normalize(nil, features: full) == [.welcome, .timer, .settings])
        #expect(FeatureChoices.normalize(nil, features: withoutTimer) == [.welcome, .settings], "Defaults are the available ones")
    }

    @Test func aStoredChoiceIsNormalized() {
        #expect(FeatureChoices.normalize(["settings", "welcome"], features: full) == [.settings, .welcome], "Order is the person's")
        #expect(FeatureChoices.normalize(["timer", "nowhere", "timer", "welcome"], features: full) == [.timer, .welcome, .settings],
                "Unknown and repeated names go; Settings is appended")
        #expect(FeatureChoices.normalize(["timer", "welcome"], features: withoutTimer) == [.welcome, .settings],
                "A feature this build left out is skipped, not failed")
        #expect(FeatureChoices.normalize(["nowhere", "elsewhere"], features: full) == [.welcome, .timer, .settings],
                "Nothing valid left means the defaults, not an empty shell")
        #expect(FeatureChoices.normalize(["welcome"], features: full) == [.welcome, .settings],
                "A stored choice gains no feature by itself, only the required one")
    }

    @Test func readingNeverWritesAndSettingStores() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let fresh = FeatureChoices(defaults: defaults, features: full)
        #expect(fresh.chosen == [.welcome, .timer, .settings])
        #expect(defaults.string(forKey: FeatureChoices.storageKey) == nil, "Opening the app stores no choice")

        fresh.set([.settings, .welcome])
        #expect(defaults.string(forKey: FeatureChoices.storageKey) == "settings,welcome")
        let again = FeatureChoices(defaults: defaults, features: full)
        #expect(again.chosen == [.settings, .welcome])
        #expect(again.defaultTab == .welcome, "Home is the fallback tab when chosen")
        again.set([.timer])
        #expect(again.chosen == [.timer, .settings])
        #expect(again.defaultTab == .timer, "Otherwise the first chosen tab")
    }

    @Test func aLinkToAHiddenFeatureRevealsItAndStoresThat() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("settings,welcome", forKey: FeatureChoices.storageKey)
        let choices = FeatureChoices(defaults: defaults, features: full)
        #expect(choices.open(link: "settings") == .select(.settings))
        #expect(choices.open(link: "timer") == .revealed(.timer))
        #expect(choices.chosen == [.settings, .welcome, .timer], "Revealed at the end")
        #expect(defaults.string(forKey: FeatureChoices.storageKey) == "settings,welcome,timer")
        #expect(choices.open(link: "timer") == .select(.timer), "Once revealed, a plain selection")
        #expect(choices.open(link: "nowhere") == .ignore)
    }

    @Test func aLinkToAFeatureThisBuildLeftOutIsReportedNotShown() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let choices = FeatureChoices(defaults: defaults, features: withoutTimer)
        #expect(choices.open(link: "timer") == .unavailable(.timer))
        #expect(choices.chosen == [.welcome, .settings], "Nothing is revealed")
        #expect(defaults.string(forKey: FeatureChoices.storageKey) == nil)
        choices.reveal(.timer)
        #expect(choices.chosen == [.welcome, .settings], "An unavailable feature can't be revealed")
    }

    @Test func theArgumentDomainSeedsAChoice() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        // The same reading a UI test's `-tabs.chosen settings,welcome` gets through the argument domain.
        defaults.set("settings, welcome", forKey: FeatureChoices.storageKey)
        #expect(FeatureChoices.stored(in: defaults) == ["settings", "welcome"], "Spaces around names are tolerated")
        #expect(FeatureChoices(defaults: defaults, features: full).chosen == [.settings, .welcome])
    }
}
#endif
