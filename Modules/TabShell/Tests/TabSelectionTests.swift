import Foundation
import Testing
@testable import TabShell

@MainActor
struct TabSelectionTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() throws {
        suiteName = "TabSelectionTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    @Test func startsOnTheHostDefault() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let selection = makeSelection()
        #expect(selection.selectedTab == .library)
    }

    @Test func restoresTheLastSelection() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeSelection()
        first.selectedTab = .settings
        #expect(defaults.string(forKey: "tabs.selected") == "settings")
        #expect(makeSelection().selectedTab == .settings)
    }

    @Test(arguments: ["removed", "Library", "", "https://example.com/settings"])
    func unknownStoredValuesUseTheDefault(_ value: String) {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(value, forKey: "tabs.selected")
        #expect(makeSelection().selectedTab == .library)
    }

    @Test func aRemovedTabUsesTheDefault() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("activity", forKey: "tabs.selected")
        let selection = TabSelection(tabs: [TestTab.library, .settings], defaultTab: .settings, defaults: defaults)
        #expect(selection.selectedTab == .settings)
    }

    @Test func deepLinkSelectionPersistsOnlyAvailableTabs() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let selection = TabSelection(tabs: [TestTab.library, .settings], defaultTab: .library, defaults: defaults)
        #expect(selection.select(rawValue: "settings"))
        #expect(selection.selectedTab == .settings)
        #expect(selection.select(rawValue: "activity") == false)
        #expect(selection.select(rawValue: "unknown") == false)
        selection.selectedTab = .activity // A binding must not bypass the same validation.
        #expect(selection.selectedTab == .settings)
        #expect(defaults.string(forKey: "tabs.selected") == "settings")
    }

    @Test func independentShellsUseIndependentKeys() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeSelection()
        first.selectedTab = .settings
        let second = TabSelection(tabs: TestTab.allCases, defaultTab: .library,
                                  storageKey: "other.tabs", defaults: defaults)
        #expect(second.selectedTab == .library)
        second.selectedTab = .activity
        #expect(first.selectedTab == .settings)
        #expect(defaults.string(forKey: "tabs.selected") == "settings")
        #expect(defaults.string(forKey: "other.tabs") == "activity")
    }

    @Test func openScenesNavigateIndependently() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeSelection()
        let second = makeSelection()
        first.selectedTab = .settings
        #expect(second.selectedTab == .library)
        second.selectedTab = .activity
        #expect(first.selectedTab == .settings)
        #expect(makeSelection().selectedTab == .activity)
    }

    private func makeSelection() -> TabSelection<TestTab> {
        TabSelection(tabs: TestTab.allCases, defaultTab: .library, defaults: defaults)
    }
}
