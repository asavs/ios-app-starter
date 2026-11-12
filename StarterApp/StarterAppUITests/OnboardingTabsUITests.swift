import XCTest

/// Onboarding's Choose your tabs step: a change applies to the tab bar and is kept by Skip and a
/// relaunch, a replay shows the stored choice, and walking through a replay leaves a custom order alone.
/// Skips without the Onboarding or TabShell modules.
final class OnboardingTabsUITests: StarterUITestCase {
    /// Features a lane may leave out, with their tab titles; the first one present is the one turned off.
    private static let optionalFeatures = [(Identifiers.Tabs.timer, "Timer"), (Identifiers.Tabs.notes, "Notes"),
                                           (Identifiers.Tabs.library, "Library")]

    @MainActor
    private func row(_ app: XCUIApplication, _ tab: String) -> XCUIElement {
        app.buttons[Identifiers.TabChoices.onboarding(tab)]
    }

    /// From the welcome sheet, Continue twice, to the tab step; fails if it isn't there.
    @MainActor
    private func continueToTabStep(_ app: XCUIApplication) {
        let next = app.buttons[ModuleIdentifiers.Onboarding.next]
        let welcomeRow = element(app, ModuleIdentifiers.Onboarding.feature("phone"))
        XCTAssertTrue(waitUntilHittable(welcomeRow, timeout: 30), "The welcome sheet should be the first step")
        let choice = app.buttons[ModuleIdentifiers.Onboarding.choice("build", "tool")]
        XCTAssertTrue(perform({ next.tap() }, until: { self.isHittable(choice) }, retryingIf: { self.isHittable(welcomeRow) }),
                      "The choice step should follow the welcome sheet")
        let settingsRow = row(app, Identifiers.Tabs.settings)
        XCTAssertTrue(perform({ next.tap() }, until: { self.isHittable(settingsRow) }, retryingIf: { self.isHittable(choice) }),
                      "Choose your tabs should follow the choice step")
    }

    /// The main path on a first launch: every available feature is offered and on, Settings can't be
    /// turned off, turning one off takes its tab away, and Skip, a replay and a relaunch all keep that.
    @MainActor
    func testChooseTabsDuringOnboarding() throws {
        let app = XCUIApplication()
        let scenario = UITestLaunch.onboarding
        app.launch(scenario)
        let next = app.buttons[ModuleIdentifiers.Onboarding.next]
        try requireModuleUI("Onboarding", appeared: next.waitForExistence(timeout: 10), "no Continue button on launch")
        let settingsTab = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        try requireModuleUI("TabShell", appeared: settingsTab.waitForExistence(timeout: 10), "no Settings tab under the flow")
        continueToTabStep(app)

        let settingsRow = row(app, Identifiers.Tabs.settings)
        XCTAssertTrue(waitUntil(settingsRow, "isSelected == true"), "Settings is on")
        XCTAssertFalse(settingsRow.isEnabled, "Settings can't be turned off")
        XCTAssertTrue(waitUntil(row(app, Identifiers.Tabs.welcome), "isSelected == true"), "A fresh install starts on the defaults")
        guard let (feature, title) = Self.optionalFeatures.first(where: { row(app, $0.0).exists }) else {
            throw XCTSkip("This build has no optional feature to turn off")
        }
        for (other, _) in Self.optionalFeatures where row(app, other).exists {
            XCTAssertTrue(waitUntil(row(app, other), "isSelected == true"), "\(other) is on by default")
        }
        attach(name: "onboarding-tabs")

        let featureRow = row(app, feature)
        XCTAssertTrue(waitUntilHittable(featureRow))
        XCTAssertTrue(perform({ featureRow.tap() }, until: { featureRow.isSelected == false },
                              retryingIf: { featureRow.isSelected }),
                      "Tapping a tab's row turns it off")
        attach(name: "onboarding-tabs-off")

        let skip = app.buttons[ModuleIdentifiers.Onboarding.skip]
        XCTAssertTrue(waitUntilHittable(skip), "The tab step can be skipped")
        skip.tap()
        XCTAssertTrue(waitUntilGone(next), "Skip closes the flow")
        let featureTab = tabButton(in: app, feature, title: title)
        XCTAssertTrue(waitUntilGone(featureTab, timeout: 10), "Skip keeps the change made on the step")
        XCTAssertTrue(tabButton(in: app, Identifiers.Tabs.welcome, title: "Home").exists, "The other tabs stay")
        XCTAssertTrue(settingsTab.exists)
        attach(name: "onboarding-tabs-applied")

        // A replay shows the stored choice, and closing it changes nothing.
        let replay = app.buttons[Identifiers.Welcome.replayTour]
        XCTAssertTrue(scroll(app, to: replay), "Home has the tour button")
        replay.tap()
        continueToTabStep(app)
        XCTAssertTrue(waitUntil(featureRow, "isSelected == false"), "A replay shows the stored choice")
        XCTAssertTrue(waitUntil(row(app, Identifiers.Tabs.welcome), "isSelected == true"))
        attach(name: "onboarding-tabs-replay")
        XCTAssertTrue(waitUntilHittable(skip))
        skip.tap()
        XCTAssertTrue(waitUntilGone(next), "Skip closes the replay")
        XCTAssertFalse(featureTab.exists, "Replaying doesn't bring a hidden tab back")

        app.terminate()
        var stored = scenario.relaunch
        stored.onboarding = .asStored
        app.launch(stored)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        XCTAssertFalse(next.waitForExistence(timeout: 3), "Onboarding stays finished")
        XCTAssertFalse(featureTab.exists, "The choice survives a relaunch")
    }

    /// An existing choice in a custom order: walking through a replay's tab step with Continue keeps the
    /// order and leaves the hidden tabs hidden.
    @MainActor
    func testReplayKeepsAnExistingChoice() throws {
        let app = XCUIApplication()
        var scenario = UITestLaunch.tab(Identifiers.Tabs.welcome)
        scenario.tabs = [Identifiers.Tabs.settings, Identifiers.Tabs.welcome]
        app.launch(scenario)
        let settingsTab = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        let homeTab = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        try requireModuleUI("TabShell", appeared: settingsTab.waitForExistence(timeout: 10), "no Settings tab")
        let replay = app.buttons[Identifiers.Welcome.replayTour]
        try requireModuleUI("Onboarding", appeared: replay.waitForExistence(timeout: 10), "no tour button")
        XCTAssertLessThan(settingsTab.frame.minX, homeTab.frame.minX, "The seeded order: Settings first")
        replay.tap()
        continueToTabStep(app)
        for (feature, _) in Self.optionalFeatures where row(app, feature).exists {
            XCTAssertTrue(waitUntil(row(app, feature), "isSelected == false"), "\(feature) stays off, as stored")
        }
        attach(name: "onboarding-tabs-existing")

        let next = app.buttons[ModuleIdentifiers.Onboarding.next]
        var taps = 0
        while next.exists, taps < 6 { // The rest of the flow: tour card, primer.
            next.tap()
            taps += 1
            _ = waitUntilSettled(next, checks: 4)
        }
        XCTAssertTrue(waitUntilGone(next), "The replay finishes")
        XCTAssertTrue(waitUntilSettled(settingsTab))
        XCTAssertLessThan(settingsTab.frame.minX, homeTab.frame.minX, "A replay keeps the order")
        for (feature, title) in Self.optionalFeatures {
            XCTAssertFalse(tabButton(in: app, feature, title: title).exists, "\(feature) stays hidden")
        }
        attach(name: "onboarding-tabs-existing-kept")
    }
}
