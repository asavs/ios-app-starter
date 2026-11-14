import XCTest

/// The Home tab: empty sections that offer their first action, a note written from Home listed as
/// recent and opened again, an item collected in the Library listed and opened from Home, shortcuts
/// that switch tabs, and sections that follow the choice of tabs. Each test writes what it needs into
/// a store of its own. Skips without TabShell, and each section without its modules.
final class HomeUITests: StarterUITestCase {
    /// Launches on Home; skips without TabShell.
    @MainActor
    private func launchHome(_ scenario: UITestLaunch) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launch(scenario)
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        try requireModuleUI("TabShell", appeared: home.waitForExistence(timeout: 10), "no Home tab")
        XCTAssertTrue(waitUntil(home, "isSelected == true"))
        return app
    }

    /// Write the first note from the empty section, find it listed on Home, open it again, and See All
    /// on the Notes tab. A shortcut switches to Settings.
    @MainActor
    func testWriteANoteFromHomeAndOpenItAgain() throws {
        let app = try launchHome(UITestLaunch(tab: Identifiers.Tabs.welcome, store: "home-notes"))
        let empty = element(app, Identifiers.Home.notesEmpty)
        try requireModuleUI("Database", appeared: empty.waitForExistence(timeout: 10), "no empty Recent Notes")
        XCTAssertTrue(element(app, Identifiers.Home.section(Identifiers.Tabs.welcome)).exists, "Shortcuts are listed")
        XCTAssertFalse(app.buttons[Identifiers.Home.shortcut(Identifiers.Tabs.welcome)].exists, "Home has no shortcut to itself")
        XCTAssertFalse(app.buttons[Identifiers.Home.seeAll(Identifiers.Tabs.notes)].exists, "Nothing to see all of yet")
        attach(name: "home-empty")

        app.buttons[Identifiers.Home.writeNote].firstMatch.tap()
        let title = app.textFields[Identifiers.Notes.Editor.title].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Write a Note opens an empty editor on Home")
        try focus(title, in: app)
        app.typeText("Groceries\n")
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        let save = app.buttons[Identifiers.Notes.Editor.save].firstMatch
        XCTAssertTrue(waitUntil(save, "isEnabled == true"), "Typing enables Save")
        save.tap()
        XCTAssertTrue(waitUntil(save, "isEnabled == false", timeout: 10), "Saved")
        app.buttons[Identifiers.Notes.Editor.done].firstMatch.tap()

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Home.notePrefix))
        let row = rows.matching(NSPredicate(format: "label CONTAINS %@", "Groceries")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The saved note is listed on Home")
        XCTAssertTrue(waitUntilGone(empty), "The empty state goes with the first note")
        attach(name: "home-recent-note")

        row.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10), "A recent note opens its editor")
        XCTAssertEqual(title.value as? String, "Groceries")
        app.buttons[Identifiers.Notes.Editor.done].firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        app.buttons[Identifiers.Home.seeAll(Identifiers.Tabs.notes)].firstMatch.tap()
        XCTAssertTrue(waitUntil(tabButton(in: app, Identifiers.Tabs.notes, title: "Notes"), "isSelected == true"),
                      "See All switches to Notes")
        let notesRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", Identifiers.Notes.rowPrefix, "Groceries"))
            .firstMatch
        XCTAssertTrue(notesRow.waitForExistence(timeout: 10), "The note is there too")

        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        home.tap()
        XCTAssertTrue(waitUntil(home, "isSelected == true"))
        let settingsShortcut = app.buttons[Identifiers.Home.shortcut(Identifiers.Tabs.settings)].firstMatch
        XCTAssertTrue(scroll(app, to: settingsShortcut), "Settings has a shortcut")
        settingsShortcut.tap()
        XCTAssertTrue(waitUntil(tabButton(in: app, Identifiers.Tabs.settings, title: "Settings"), "isSelected == true"),
                      "The shortcut switches to Settings")
    }

    /// The empty Library section opens the Library tab; a link collected there is listed on Home and
    /// opens its detail from Home.
    @MainActor
    func testCollectedItemShowsOnHome() throws {
        let app = try launchHome(UITestLaunch(tab: Identifiers.Tabs.welcome, store: "home-library",
                                              extra: ["-attachments.fakeLink", "Training Plan"]))
        let empty = element(app, Identifiers.Home.libraryEmpty)
        try requireModuleUI("Attachments", appeared: empty.waitForExistence(timeout: 10), "no empty Recently Collected")
        let open = app.buttons[Identifiers.Home.openLibrary].firstMatch
        XCTAssertTrue(scroll(app, to: open))
        open.tap()
        XCTAssertTrue(waitUntil(tabButton(in: app, Identifiers.Tabs.library, title: "Library"), "isSelected == true"),
                      "Open Library switches to the Library")
        XCTAssertTrue(element(app, Identifiers.Library.empty).waitForExistence(timeout: 10))

        app.buttons[ModuleIdentifiers.Attachments.add].firstMatch.tap()
        app.buttons[ModuleIdentifiers.Attachments.addLink].firstMatch.tap()
        let linkField = app.textFields[ModuleIdentifiers.Attachments.linkField].firstMatch
        let field = linkField.exists ? linkField : app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Adding a link asks for the address")
        field.tap()
        field.typeText("www.example.com/plan")
        app.buttons[ModuleIdentifiers.Attachments.linkAdd].firstMatch.tap()
        XCTAssertTrue(waitUntilGone(element(app, Identifiers.Library.empty)), "The link is collected")

        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        home.tap()
        XCTAssertTrue(waitUntil(home, "isSelected == true"))
        let item = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Home.itemPrefix)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), "The collected link is listed on Home")
        XCTAssertTrue(waitUntilGone(empty))
        XCTAssertTrue(scroll(app, to: item))
        attach(name: "home-recent-item")
        item.tap()
        XCTAssertTrue(app.textFields[Identifiers.Library.Detail.title].firstMatch.waitForExistence(timeout: 10),
                      "A recent item opens its detail")
        attach(name: "home-item-detail")
    }

    /// With only Home and Settings chosen, Home shows no Notes or Library section and one shortcut.
    @MainActor
    func testHomeFollowsTheChosenTabs() throws {
        var scenario = UITestLaunch.tab(Identifiers.Tabs.welcome)
        scenario.tabs = [Identifiers.Tabs.welcome, Identifiers.Tabs.settings]
        let app = try launchHome(scenario)
        let settingsShortcut = app.buttons[Identifiers.Home.shortcut(Identifiers.Tabs.settings)].firstMatch
        try requireModuleUI("Settings", appeared: settingsShortcut.waitForExistence(timeout: 10), "no Settings shortcut")
        XCTAssertFalse(element(app, Identifiers.Home.section(Identifiers.Tabs.notes)).exists, "No Notes section without its tab")
        XCTAssertFalse(element(app, Identifiers.Home.section(Identifiers.Tabs.library)).exists, "No Library section without its tab")
        let shortcuts = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Home.shortcutPrefix))
        XCTAssertEqual(shortcuts.count, 1, "One shortcut: Settings")
        attach(name: "home-chosen-tabs")
    }
}
