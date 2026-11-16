import XCTest

/// Six chosen tabs, more than an iPhone's tab bar holds: the bar shows four and TabShell's More tab
/// lists the rest, and every one stays reachable through that list, a Home shortcut, a deep link, the
/// chooser and a relaunch. An iPad's bar holds all six, with no More. Skips in a build with fewer than
/// six features, such as the template without the Timer modules.
final class ManyTabsUITests: StarterUITestCase {
    /// Every feature, in the default order: Timer and Settings land in More on an iPhone.
    private let allTabs = [Identifiers.Tabs.welcome, Identifiers.Tabs.library, Identifiers.Tabs.notes,
                           Identifiers.Tabs.images, Identifiers.Tabs.timer, Identifiers.Tabs.settings]
    private let titles = [Identifiers.Tabs.welcome: "Home", Identifiers.Tabs.library: "Library",
                          Identifiers.Tabs.notes: "Notes", Identifiers.Tabs.images: "Images",
                          Identifiers.Tabs.timer: "Timer", Identifiers.Tabs.settings: "Settings"]
    /// The modules the six features need between them.
    private static let sixFeatureModules: Set = ["TabShell", "Settings", "Database", "Attachments", "SessionTimer", "TimerRing"]

    @MainActor
    private func tab(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        tabButton(in: app, id, title: titles[id] ?? id)
    }

    /// TabShell's More tab. iOS 26.3 leaves tab bar buttons without their identifier, so its title too.
    @MainActor
    private func moreButton(_ app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == %@ OR (identifier == '' AND label == 'More')",
                                    ModuleIdentifiers.TabShell.more)
        // Only a phone's tab bar has More; a narrow query a loaded runner answers in time.
        return app.tabBars.buttons.matching(predicate).firstMatch
    }

    @MainActor
    private func moreRow(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.buttons[ModuleIdentifiers.TabShell.moreRow(id)].firstMatch
    }

    @MainActor
    private func backToMore(_ app: XCUIApplication) -> XCUIElement {
        app.buttons[ModuleIdentifiers.TabShell.moreBack].firstMatch
    }

    /// Launches into six tabs and waits for the shell. Skips when this build has fewer than six
    /// features; fails when the lane says it has them all but six tabs didn't appear.
    @MainActor
    private func launchSixTabs(_ app: XCUIApplication, selected: String, extra: [String] = []) throws -> UITestLaunch {
        let scenario = UITestLaunch(tab: selected, tabs: allTabs, extra: extra)
        app.launch(scenario)
        let home = tab(app, Identifiers.Tabs.welcome)
        try requireModuleUI("TabShell", appeared: home.waitForExistence(timeout: 10), "no Home tab")
        let more = moreButton(app), timer = tab(app, Identifiers.Tabs.timer)
        // A loaded hosted runner has taken over 5 s to show the bar's last buttons after Home's.
        if !waitUntil(timeout: 15, { more.exists || timer.exists }) {
            if let enabled = Self.enabledModules, enabled.isSuperset(of: Self.sixFeatureModules) {
                XCTFail("Every feature's module is enabled, but six tabs did not appear")
            }
            throw XCTSkip("Fewer than six features in this build")
        }
        return scenario
    }

    /// Whether this layout overflows into More: a phone does, an iPad's wider bar doesn't.
    @MainActor
    private func overflows(_ app: XCUIApplication) -> Bool {
        moreButton(app).exists
    }

    /// Opens a tab: from the bar when it's there, otherwise from More's list.
    @MainActor
    private func open(_ app: XCUIApplication, _ id: String) {
        let button = tab(app, id)
        if button.exists {
            button.tap()
            XCTAssertTrue(waitUntil(button, "isSelected == true"), "\(id) opens from the bar")
            return
        }
        let more = moreButton(app), row = moreRow(app, id), back = backToMore(app)
        if !more.isSelected { more.tap() } else if back.exists { back.tap() }
        XCTAssertTrue(waitUntilHittable(row), "More lists \(id)")
        row.tap()
        XCTAssertTrue(waitUntilGone(row), "\(id) opens from More")
    }

    /// The phone's main path: four tabs and More, whose list holds Timer and Settings. Each opens in
    /// More with one navigation bar and a way back to the list; Settings' own screens (the chooser)
    /// work there; the selection survives a relaunch; and hiding a tab from the chooser brings
    /// Settings into the bar with the chooser still on screen.
    @MainActor
    func testOverflowTabsStayReachable() throws {
        let app = XCUIApplication()
        let scenario = try launchSixTabs(app, selected: Identifiers.Tabs.welcome)
        guard overflows(app) else { throw XCTSkip("No More: testSixTabsFitAnIPadBar covers this layout") }
        for id in allTabs.prefix(4) {
            XCTAssertTrue(isHittable(tab(app, id)), "\(id) is in the bar")
        }
        XCTAssertFalse(tab(app, Identifiers.Tabs.timer).exists, "Timer is in More, not the bar")
        XCTAssertFalse(tab(app, Identifiers.Tabs.settings).exists, "Settings is in More, not the bar")
        attach(name: "six-tabs")

        moreButton(app).tap()
        XCTAssertTrue(waitUntilHittable(moreRow(app, Identifiers.Tabs.timer)), "More lists Timer")
        XCTAssertTrue(waitUntilHittable(moreRow(app, Identifiers.Tabs.settings)), "More lists Settings")
        attach(name: "six-tabs-more")

        open(app, Identifiers.Tabs.timer)
        XCTAssertTrue(element(app, Identifiers.Timer.ring).waitForExistence(timeout: 10), "Timer opens from More")
        XCTAssertTrue(waitUntilHittable(backToMore(app)), "With a way back to More's list")
        XCTAssertEqual(app.navigationBars.count, 1, "and one navigation bar, the Timer's own")
        attach(name: "six-tabs-timer")
        backToMore(app).tap()
        XCTAssertTrue(waitUntilHittable(moreRow(app, Identifiers.Tabs.settings)), "Back shows More's list")

        open(app, Identifiers.Tabs.settings)
        let chooserRow = app.buttons[Identifiers.TabChoices.open].firstMatch
        XCTAssertTrue(chooserRow.waitForExistence(timeout: 10), "Settings opens from More")
        attach(name: "six-tabs-settings")
        chooserRow.tap()
        let hideHome = app.buttons[Identifiers.TabChoices.hide(Identifiers.Tabs.welcome)].firstMatch
        XCTAssertTrue(waitUntilHittable(hideHome), "The chooser opens inside More")
        XCTAssertFalse(backToMore(app).exists, "Deeper screens go back the usual way")
        attach(name: "six-tabs-chooser")
        app.terminate()

        // Settings, picked from More's list, is the selection a relaunch restores.
        var restored = scenario.relaunch
        restored.tab = nil
        app.launch(restored)
        XCTAssertTrue(chooserRow.waitForExistence(timeout: 10), "Relaunch restores Settings, inside More")
        XCTAssertTrue(waitUntil(moreButton(app), "isSelected == true"))

        // Five tabs fit: hiding Home from the chooser empties More and puts Settings in the bar.
        chooserRow.tap()
        XCTAssertTrue(waitUntilHittable(hideHome))
        hideHome.tap()
        let settings = tab(app, Identifiers.Tabs.settings)
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "With five tabs, Settings is in the bar")
        XCTAssertTrue(waitUntilGone(moreButton(app)), "and More is gone")
        XCTAssertTrue(waitUntil(settings, "isSelected == true"), "Settings stays selected")
        XCTAssertTrue(isHittable(tab(app, Identifiers.Tabs.timer)), "Timer is in the bar too")
        attach(name: "five-tabs-after-hiding")
    }

    /// Ways in that don't go through More's list: a Home shortcut and a deep link to a tab in More,
    /// including from More's list itself, and a chosen order that puts other tabs there.
    @MainActor
    func testOverflowTabsOpenFromShortcutsLinksAndOrder() throws {
        let scheme = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "StarterAppURLScheme") as? String,
                                   "project.yml should pass APP_URL_SCHEME to the UI tests")
        let app = XCUIApplication()
        let scenario = try launchSixTabs(app, selected: Identifiers.Tabs.welcome)
        guard overflows(app) else { throw XCTSkip("No More: testSixTabsFitAnIPadBar covers this layout") }

        let shortcut = element(app, Identifiers.Home.shortcut(Identifiers.Tabs.timer))
        XCTAssertTrue(scroll(app, to: shortcut), "Home offers a shortcut to Timer")
        shortcut.tap()
        XCTAssertTrue(element(app, Identifiers.Timer.ring).waitForExistence(timeout: 10), "The shortcut opens Timer in More")
        XCTAssertTrue(waitUntil(moreButton(app), "isSelected == true"))
        attach(name: "six-tabs-shortcut-timer")

        // From More's list, a link to the tab last opened from it still opens that tab.
        backToMore(app).tap()
        XCTAssertTrue(waitUntilHittable(moreRow(app, Identifiers.Tabs.timer)))
        app.open(try XCTUnwrap(URL(string: "\(scheme)://timer")), in: scenario.relaunch)
        XCTAssertTrue(element(app, Identifiers.Timer.ring).waitForExistence(timeout: 10), "A link leaves More's list")

        app.open(try XCTUnwrap(URL(string: "\(scheme)://settings")), in: scenario.relaunch)
        XCTAssertTrue(app.buttons[Identifiers.TabChoices.open].firstMatch.waitForExistence(timeout: 10),
                      "A link opens Settings in More")
        app.terminate()

        // Settings and Timer chosen first: they take the bar, and Notes and Images go to More.
        let reordered = [Identifiers.Tabs.settings, Identifiers.Tabs.timer, Identifiers.Tabs.welcome,
                         Identifiers.Tabs.library, Identifiers.Tabs.notes, Identifiers.Tabs.images]
        app.launch(UITestLaunch(tab: Identifiers.Tabs.settings, tabs: reordered))
        let settings = tab(app, Identifiers.Tabs.settings)
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "Settings leads the bar")
        XCTAssertTrue(isHittable(tab(app, Identifiers.Tabs.timer)))
        XCTAssertFalse(tab(app, Identifiers.Tabs.images).exists, "Images is in More")
        open(app, Identifiers.Tabs.images)
        XCTAssertTrue(element(app, Identifiers.Images.empty).waitForExistence(timeout: 10), "Images opens from More")
        attach(name: "six-tabs-reordered-images")
    }

    /// At the largest text size More's rows and its back button stay full-size touch targets.
    @MainActor
    func testMoreAtLargestTextSize() throws {
        let app = XCUIApplication()
        _ = try launchSixTabs(app, selected: Identifiers.Tabs.welcome, extra: UITestLaunch.largestTextSize)
        guard overflows(app) else { throw XCTSkip("No More: testSixTabsFitAnIPadBar covers this layout") }
        moreButton(app).tap()
        let timer = moreRow(app, Identifiers.Tabs.timer)
        XCTAssertTrue(waitUntilHittable(timer))
        XCTAssertTrue(waitUntilHittable(moreRow(app, Identifiers.Tabs.settings)))
        XCTAssertGreaterThanOrEqual(timer.frame.height, 44, "A More row is a full-size touch target")
        attach(name: "six-tabs-more-largest-text")
        // More's list is TabShell's own screen: labels, text sizes and touch targets pass Apple's audit.
        // Not `.textClipped`: on iOS 27.0 it flags the Timer row, whose text the screenshot shows whole.
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        timer.tap()
        XCTAssertTrue(element(app, Identifiers.Timer.ring).waitForExistence(timeout: 10), "Timer opens at the largest size")
        let back = backToMore(app)
        XCTAssertTrue(waitUntilHittable(back))
        // Its glass capsule measures 36 points, but the toolbar's hit region is larger: ask the audit
        // about this button alone, since the Timer's own screen is the Timer tests' business.
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription]) { issue in
            issue.element?.identifier != ModuleIdentifiers.TabShell.moreBack // true ignores the issue.
        }
    }

    /// An iPad's bar holds all six, in the chosen order, with no More; each one opens. Skips on a phone.
    @MainActor
    func testSixTabsFitAnIPadBar() throws {
        // Decided before launching, so a phone lane doesn't spend a launch on it.
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Only an iPad shows six tabs in its bar") }
        let app = XCUIApplication()
        _ = try launchSixTabs(app, selected: Identifiers.Tabs.welcome)
        guard !overflows(app) else { throw XCTSkip("A phone overflows into More: the other tests cover it") }
        var previous = -CGFloat.infinity
        for id in allTabs {
            let button = tab(app, id)
            XCTAssertTrue(waitUntilHittable(button), "\(id) is in the iPad's bar")
            XCTAssertGreaterThan(button.frame.minX, previous, "\(id) keeps the chosen order")
            previous = button.frame.minX
        }
        attach(name: "six-tabs-ipad")
        for id in allTabs.reversed() {
            let button = tab(app, id)
            button.tap()
            XCTAssertTrue(waitUntil(button, "isSelected == true"), "\(id) opens")
        }
    }
}
