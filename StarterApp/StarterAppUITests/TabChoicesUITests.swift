import XCTest

/// Settings' chooser of tabs: order and visibility follow it and survive a relaunch, a saved selection
/// that can't be shown falls back, and hiding a tab loses neither a running timer nor an unsaved note.
final class TabChoicesUITests: StarterUITestCase {
    /// Opens the chooser from the Settings tab; skips without the modules it needs.
    @MainActor
    private func openChooser(_ app: XCUIApplication) throws {
        let settings = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        try requireModuleUI("TabShell", appeared: settings.waitForExistence(timeout: 10), "no Settings tab")
        settings.tap()
        XCTAssertTrue(waitUntil(settings, "isSelected == true"))
        let row = app.buttons[Identifiers.TabChoices.open].firstMatch
        try requireModuleUI("Settings", appeared: row.waitForExistence(timeout: 10), "no Tabs row")
        row.tap()
    }

    @MainActor
    private func hideButton(_ app: XCUIApplication, _ tab: String) -> XCUIElement {
        app.buttons[Identifiers.TabChoices.hide(tab)].firstMatch
    }

    @MainActor
    private func showButton(_ app: XCUIApplication, _ tab: String) -> XCUIElement {
        app.buttons[Identifiers.TabChoices.show(tab)].firstMatch
    }

    /// Drags Settings' handle over the first row, Home's, and waits for Settings to lead the tab bar. A
    /// fast drag lands before the list has picked the row up, so it goes slowly and holds over the top.
    /// The handle's label is the system's, with the row's text. A loaded runner has dropped the whole
    /// drag (Settings stayed last), so it is repeated once if the tab bar kept its order.
    @MainActor
    private func dragSettingsToTheTop(_ app: XCUIApplication, above firstRowButton: XCUIElement) {
        let handle = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder' AND label CONTAINS 'Settings'")).firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "Shown rows have a drag handle")
        let settings = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        // Tabs come and go while the shell rebuilds; a missing one answers neither order.
        let settingsLeads = { settings.exists && home.exists && settings.frame.minX < home.frame.minX }
        let homeLeads = { settings.exists && home.exists && home.frame.minX < settings.frame.minX }
        let drag = {
            let top = firstRowButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
                .withOffset(CGVector(dx: handle.frame.midX - firstRowButton.frame.midX, dy: -5))
            handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.5, thenDragTo: top, withVelocity: .slow, thenHoldForDuration: 0.5)
        }
        XCTAssertTrue(perform(drag, until: settingsLeads, retryingIf: homeLeads), "The drag reorders the tab bar")
    }

    /// The main path: Settings can't be hidden, a drag reorders, hiding takes the tab away and showing
    /// brings it back, the chooser stays open throughout, and all of it is there after a relaunch.
    @MainActor
    func testChooseReorderHideAndKeepTabs() throws {
        let app = XCUIApplication()
        let scenario = UITestLaunch.tab(Identifiers.Tabs.welcome)
        app.launch(scenario)
        try openChooser(app)
        let settings = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        let hideHome = hideButton(app, Identifiers.Tabs.welcome)
        XCTAssertTrue(hideHome.waitForExistence(timeout: 10), "The chooser offers to hide Home")
        XCTAssertFalse(hideButton(app, Identifiers.Tabs.settings).exists, "Settings can't be hidden")
        attach(name: "tab-choices")

        XCTAssertLessThan(home.frame.minX, settings.frame.minX, "Home starts first")
        dragSettingsToTheTop(app, above: hideHome)
        XCTAssertTrue(waitUntilSettled(settings))
        XCTAssertLessThan(settings.frame.minX, home.frame.minX, "The drag reorders the tab bar")
        XCTAssertTrue(hideHome.waitForExistence(timeout: 10), "Reordering leaves the chooser open")
        XCTAssertTrue(waitUntilSettled(settings))
        attach(name: "tab-choices-reordered") // Check by eye: iOS 27.0 can draw a moved tab with another's symbol.

        // Hide Home; its tab goes and it moves to Hidden.
        XCTAssertTrue(waitUntilHittable(hideHome))
        hideHome.tap()
        XCTAssertTrue(waitUntilGone(home, timeout: 10), "Hiding takes the tab away")
        let showHome = showButton(app, Identifiers.Tabs.welcome)
        XCTAssertTrue(showHome.waitForExistence(timeout: 5), "A hidden feature can be shown again")
        XCTAssertTrue(waitUntil(settings, "isSelected == true"), "Settings stays selected")
        attach(name: "tab-choices-hidden")
        app.terminate()

        // Neither the choice nor the selection pinned: both come from what the app stored.
        var restored = scenario.relaunch
        restored.tab = nil
        app.launch(restored)
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertFalse(home.exists, "A hidden tab stays hidden after a relaunch")
        try openChooser(app)
        XCTAssertTrue(showHome.waitForExistence(timeout: 10))
        showHome.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 10), "Showing brings the tab back")
        XCTAssertLessThan(settings.frame.minX, home.frame.minX, "At the end, after the moved Settings")
        home.tap()
        XCTAssertTrue(waitUntil(home, "isSelected == true"), "And it opens")
        app.terminate()

        app.launch(restored)
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertLessThan(settings.frame.minX, home.frame.minX, "The order survives a relaunch")
    }

    /// A saved tab that doesn't exist, or that the choice leaves out, opens on Home rather than nothing,
    /// and a stored choice with nothing valid in it shows the defaults.
    @MainActor
    func testInvalidSavedSelectionAndChoiceFallBack() throws {
        let app = XCUIApplication()
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        let settings = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")

        app.launch(UITestLaunch(tab: "nowhere"))
        try requireModuleUI("TabShell", appeared: home.waitForExistence(timeout: 10), "no Home tab")
        XCTAssertTrue(waitUntil(home, "isSelected == true"), "An unknown saved tab opens Home")
        app.terminate()

        app.launch(UITestLaunch(tab: Identifiers.Tabs.notes, tabs: [Identifiers.Tabs.settings, Identifiers.Tabs.welcome]))
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(home, "isSelected == true"), "A saved tab that's hidden opens Home")
        XCTAssertFalse(tabButton(in: app, Identifiers.Tabs.notes, title: "Notes").exists)
        app.terminate()

        app.launch(UITestLaunch(tab: Identifiers.Tabs.settings, tabs: ["nowhere", "elsewhere"]))
        XCTAssertTrue(home.waitForExistence(timeout: 10), "Nothing valid in the choice means the defaults")
        XCTAssertTrue(settings.exists)
        XCTAssertTrue(waitUntil(settings, "isSelected == true"))
    }

    /// Reordering and hiding the Timer tab mid-session stop nothing: showing it again, or a link to it,
    /// finds the same session running.
    @MainActor
    func testHidingTheTimerKeepsItsSession() throws {
        let scheme = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "StarterAppURLScheme") as? String,
                                   "project.yml should pass APP_URL_SCHEME to the UI tests")
        let app = XCUIApplication()
        let scenario = UITestLaunch(tab: Identifiers.Tabs.timer, extra: ["-timer.intervals", "600,10,3"])
        app.launch(scenario)
        let primary = element(app, Identifiers.Timer.primary)
        try requireModuleUI("SessionTimer", appeared: primary.waitForExistence(timeout: 10), "no Start button on the Timer tab")
        let timerTab = tabButton(in: app, Identifiers.Tabs.timer, title: "Timer")
        try requireModuleUI("TabShell", appeared: timerTab.waitForExistence(timeout: 5), "no Timer tab")
        primary.tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Pause'"), "The session should start")
        let step = element(app, Identifiers.Timer.step)

        try openChooser(app)
        let hideTimer = hideButton(app, Identifiers.Tabs.timer)
        XCTAssertTrue(hideTimer.waitForExistence(timeout: 10))
        dragSettingsToTheTop(app, above: hideButton(app, Identifiers.Tabs.welcome))
        XCTAssertTrue(hideTimer.waitForExistence(timeout: 10), "Reordering leaves the chooser open")
        XCTAssertTrue(waitUntilHittable(hideTimer))
        hideTimer.tap()
        XCTAssertTrue(waitUntilGone(timerTab, timeout: 10), "Hiding takes the tab away")
        attach(name: "tab-choices-timer-hidden")
        let showTimer = showButton(app, Identifiers.Tabs.timer)
        XCTAssertTrue(showTimer.waitForExistence(timeout: 5))
        showTimer.tap()
        XCTAssertTrue(timerTab.waitForExistence(timeout: 10))
        timerTab.tap()
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertEqual(primary.label, "Pause", "The session kept running while its tab was hidden")
        XCTAssertEqual(step.label, "Step 1 of 5", "The same session, in its first phase")

        // Hidden again, then a link: the tab comes back selected, on the same session. The Settings
        // tab kept the chooser open while the tab bar changed around it.
        tabButton(in: app, Identifiers.Tabs.settings, title: "Settings").tap()
        XCTAssertTrue(hideTimer.waitForExistence(timeout: 10))
        hideTimer.tap()
        XCTAssertTrue(waitUntilGone(timerTab, timeout: 10))
        app.open(try XCTUnwrap(URL(string: "\(scheme)://timer")), in: scenario.relaunch)
        XCTAssertTrue(timerTab.waitForExistence(timeout: 10), "The link should reveal the Timer tab")
        XCTAssertTrue(waitUntil(timerTab, "isSelected == true"), "And select it")
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        XCTAssertEqual(primary.label, "Pause", "Still the running session")
        element(app, Identifiers.Timer.reset).tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Start'"))
    }

    /// Reordering and hiding with text unsaved in Notes: the draft is listed when the tab comes back, with its text.
    @MainActor
    func testHidingNotesKeepsAnUnsavedNote() throws {
        let app = XCUIApplication()
        app.launch(UITestLaunch(tab: Identifiers.Tabs.notes))
        let notesTab = tabButton(in: app, Identifiers.Tabs.notes, title: "Notes")
        try requireModuleUI("TabShell", appeared: notesTab.waitForExistence(timeout: 10), "no Notes tab")
        let add = app.buttons[Identifiers.Notes.add].firstMatch
        try requireModuleUI("Database", appeared: add.waitForExistence(timeout: 10), "no Add button on the Notes tab")
        add.tap()
        let title = app.textFields[Identifiers.Notes.Editor.title].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        try focus(title, in: app)
        app.typeText("Shopping\n") // Return puts the keyboard away; it covers the tab bar otherwise.
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))

        try openChooser(app)
        let hideNotes = hideButton(app, Identifiers.Tabs.notes)
        XCTAssertTrue(hideNotes.waitForExistence(timeout: 10))
        dragSettingsToTheTop(app, above: hideButton(app, Identifiers.Tabs.welcome))
        XCTAssertTrue(hideNotes.waitForExistence(timeout: 10), "Reordering leaves the chooser open")
        XCTAssertTrue(waitUntilHittable(hideNotes))
        hideNotes.tap()
        XCTAssertTrue(waitUntilGone(notesTab, timeout: 10), "Hiding takes the tab away")
        let showNotes = showButton(app, Identifiers.Tabs.notes)
        XCTAssertTrue(showNotes.waitForExistence(timeout: 5))
        showNotes.tap()
        XCTAssertTrue(notesTab.waitForExistence(timeout: 10))
        notesTab.tap()
        XCTAssertTrue(waitUntil(notesTab, "isSelected == true"))

        let draft = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS 'Shopping'", Identifiers.Notes.rowPrefix)).firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 10), "The unsaved note is listed")
        attach(name: "tab-choices-note-kept")
        draft.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, "Shopping", "With its text")
    }

    /// At the largest accessibility text size the rows wrap and scroll, and their controls stay reachable.
    @MainActor
    func testChooserAtLargestTextSize() throws {
        let app = XCUIApplication()
        app.launch(UITestLaunch(tab: Identifiers.Tabs.settings, tabs: [Identifiers.Tabs.welcome, Identifiers.Tabs.settings],
                                extra: UITestLaunch.largestTextSize))
        let tabs = app.buttons[Identifiers.TabChoices.open].firstMatch
        try requireModuleUI("Settings", appeared: tabs.waitForExistence(timeout: 10), "no Tabs row")
        XCTAssertTrue(scroll(app, to: tabs))
        tabs.tap()
        let hideHome = hideButton(app, Identifiers.Tabs.welcome)
        XCTAssertTrue(waitUntilHittable(hideHome), "The first row's control is on screen")
        attach(name: "tab-choices-largest-text")
        hideHome.tap()
        let showHome = showButton(app, Identifiers.Tabs.welcome)
        XCTAssertTrue(scroll(app, to: showHome), "A hidden feature can be reached by scrolling")
        attach(name: "tab-choices-largest-text-hidden")
    }

    /// Erase Local Data forgets the choice, and the tabs follow without a relaunch.
    @MainActor
    func testEraseLocalDataBringsBackTheDefaultTabs() throws {
        let app = XCUIApplication()
        app.launch(.tab(Identifiers.Tabs.settings))
        try openChooser(app)
        let hideHome = hideButton(app, Identifiers.Tabs.welcome)
        XCTAssertTrue(hideHome.waitForExistence(timeout: 10))
        hideHome.tap()
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        XCTAssertTrue(waitUntilGone(home, timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        let reset = app.buttons[ModuleIdentifiers.Settings.reset]
        XCTAssertTrue(scroll(app, to: reset))
        reset.tap()
        let confirm = app.buttons[ModuleIdentifiers.Settings.resetConfirm].firstMatch
        let erase = confirm.waitForExistence(timeout: 3) ? confirm : app.buttons["Erase"].firstMatch
        XCTAssertTrue(erase.waitForExistence(timeout: 5))
        erase.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 10), "The hidden tab is back")
    }
}
