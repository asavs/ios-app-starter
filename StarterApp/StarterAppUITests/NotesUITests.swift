import XCTest

/// The Notes tab: write and save a note, keep an unsaved draft across a tab switch, search, edit,
/// relaunch, refer to a Library item (with Attachments), and delete with the confirmation. One test
/// did all of it until it passed XCTest's five-minute allowance on a loaded runner, where a timed-out
/// test gets no second attempt (2026-11-08); each test now writes the note it needs.
final class NotesUITests: StarterUITestCase {
    private let scenario = UITestLaunch(tab: Identifiers.Tabs.notes, store: "notes",
                                        extra: ["-attachments.fakeCamera", "YES", "-attachments.fakeLink", "Training Plan"])

    /// The Notes tab's elements the tests share.
    @MainActor
    private struct Screen {
        let app: XCUIApplication
        var empty: XCUIElement { app.descendants(matching: .any).matching(identifier: Identifiers.Notes.empty).firstMatch }
        var add: XCUIElement { app.buttons[Identifiers.Notes.add].firstMatch }
        var title: XCUIElement { app.textFields[Identifiers.Notes.Editor.title].firstMatch }
        var body: XCUIElement { app.textViews[Identifiers.Notes.Editor.body].firstMatch }
        var save: XCUIElement { app.buttons[Identifiers.Notes.Editor.save].firstMatch }
        var done: XCUIElement { app.buttons[Identifiers.Notes.Editor.done].firstMatch }
        var rows: XCUIElementQuery {
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Notes.rowPrefix))
        }
        func row(containing text: String) -> XCUIElement {
            rows.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        }
    }

    /// Launches on an empty Notes tab with a store of its own; skips without the modules it needs.
    @MainActor
    private func launchEmpty() throws -> Screen {
        let app = XCUIApplication()
        app.launch(scenario)
        let screen = Screen(app: app)
        let notesTab = tabButton(in: app, Identifiers.Tabs.notes, title: "Notes")
        try requireModuleUI("TabShell", appeared: notesTab.waitForExistence(timeout: 10), "no Notes tab")
        try requireModuleUI("Database", appeared: screen.empty.waitForExistence(timeout: 10), "no empty Notes state")
        return screen
    }

    /// Writes and saves a note, then leaves the editor: Save keeps it open, Done leaves.
    @MainActor
    private func write(_ screen: Screen, title text: String, body bodyText: String) throws {
        let app = screen.app
        screen.add.tap()
        XCTAssertTrue(screen.title.waitForExistence(timeout: 10), "Add opens an empty editor")
        XCTAssertFalse(screen.save.isEnabled, "Nothing to save yet")
        try focus(screen.title, in: app)
        app.typeText(text + "\n") // Return puts the keyboard away, so focusing the body below waits for it to come back.
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        try focus(screen.body, in: app)
        app.typeText(bodyText)
        XCTAssertTrue(waitUntil(screen.save, "isEnabled == true", timeout: 15), "Typing enables Save")
        screen.save.tap()
        XCTAssertTrue(waitUntil(screen.save, "isEnabled == false", timeout: 10), "Saved: nothing left to save")
        screen.done.tap()
        XCTAssertTrue(screen.row(containing: text).waitForExistence(timeout: 10), "The saved note is listed")
        XCTAssertTrue(waitUntilGone(screen.empty))
    }

    /// Writing and saving a note, and a second one typed but not saved: it survives switching tabs,
    /// leaving it asks, Keep Editing stays and Discard drops it.
    @MainActor
    func testWriteSaveAndKeepAnUnsavedDraft() throws {
        let screen = try launchEmpty()
        let app = screen.app
        attach(name: "notes-empty")
        try write(screen, title: "Monday", body: "Three rounds, then rest.")
        attach(name: "notes-saved")

        screen.add.tap()
        XCTAssertTrue(screen.title.waitForExistence(timeout: 10))
        try focus(screen.title, in: app)
        app.typeText("Shopping\n") // Return puts the keyboard away; it covers the tab bar otherwise.
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        let notesTab = tabButton(in: app, Identifiers.Tabs.notes, title: "Notes")
        home.tap()
        XCTAssertTrue(waitUntil(home, "isSelected == true"))
        notesTab.tap()
        XCTAssertTrue(waitUntil(notesTab, "isSelected == true"))
        XCTAssertTrue(screen.title.waitForExistence(timeout: 10), "The editor is where it was")
        XCTAssertEqual(screen.title.value as? String, "Shopping", "With the draft")
        screen.done.tap()
        let discard = app.buttons[Identifiers.Notes.Editor.discard].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "Leaving with unsaved changes asks")
        attach(name: "notes-unsaved-changes")
        // iOS 27 shows the dialog as a popover without its cancel button: a tap outside keeps editing.
        let keepEditing = app.buttons["Keep Editing"].firstMatch
        if keepEditing.exists {
            keepEditing.tap()
        } else {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
        }
        XCTAssertTrue(waitUntilGone(discard, timeout: 5))
        XCTAssertTrue(screen.title.exists, "Keep Editing stays")
        screen.done.tap()
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(screen.row(containing: "Monday").waitForExistence(timeout: 10), "Discard leaves the list as it was")
        XCTAssertFalse(screen.row(containing: "Shopping").exists, "The discarded draft is gone")
    }

    /// Search by body text and to no results; edit a saved note, refer to a Library item (with
    /// Attachments), and find all of it after a relaunch into the same store.
    @MainActor
    func testSearchEditAndKeepAfterRelaunch() throws {
        let screen = try launchEmpty()
        let app = screen.app
        try write(screen, title: "Monday", body: "Three rounds, then rest.")
        let monday = screen.row(containing: "Monday")

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        try focus(searchField, in: app)
        app.typeText("rounds")
        XCTAssertTrue(monday.exists, "The body matches")
        app.typeText("zzz")
        XCTAssertTrue(element(app, Identifiers.Notes.noResults).waitForExistence(timeout: 10))
        attach(name: "notes-no-results")
        let close = app.buttons["Close"].firstMatch
        (close.exists ? close : app.buttons["Cancel"].firstMatch).tap()
        XCTAssertTrue(waitUntil(monday, "exists == true", timeout: 10))

        // Edit the note; a Library item can be attached once the note is saved.
        monday.tap()
        XCTAssertTrue(screen.title.waitForExistence(timeout: 10))
        try focus(screen.body, in: app)
        app.typeText(" Stretch after.")
        XCTAssertTrue(waitUntil(screen.save, "isEnabled == true", timeout: 15))
        screen.save.tap()
        XCTAssertTrue(waitUntil(screen.save, "isEnabled == false", timeout: 10))
        try focus(screen.title, in: app)
        app.typeText("\n") // Return in the title puts the keyboard away; it covers the rows below.
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        let addReference = app.buttons[Identifiers.Notes.Editor.addReference].firstMatch
        if Self.enabledModules?.contains("Attachments") ?? addReference.exists {
            try linkALibraryItem(app, addReference: addReference)
        }
        screen.done.tap()

        app.terminate()
        app.launch(scenario.relaunch)
        XCTAssertTrue(monday.waitForExistence(timeout: 10), "The note survives a relaunch")
        monday.tap()
        XCTAssertTrue(screen.body.waitForExistence(timeout: 10))
        let text = screen.body.value as? String ?? ""
        XCTAssertTrue(text.contains("Three rounds, then rest.") && text.contains("Stretch after."), "With its edited text, got: \(text)")
        if addReference.exists {
            let references = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Notes.Editor.referencePrefix))
            XCTAssertTrue(references.firstMatch.waitForExistence(timeout: 10), "And its Library item")
        }
        screen.done.tap()
    }

    /// Deleting asks first: Cancel keeps the note, Delete removes it and the empty state comes back.
    @MainActor
    func testDeleteAsksFirst() throws {
        let screen = try launchEmpty()
        let app = screen.app
        try write(screen, title: "Monday", body: "Three rounds, then rest.")
        let monday = screen.row(containing: "Monday")

        monday.swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "A swipe offers Delete")
        delete.tap()
        let confirm = app.buttons[Identifiers.Notes.deleteConfirm].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Deleting asks first")
        attach(name: "notes-delete-confirmation")
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap() // Outside the popover.
        }
        XCTAssertTrue(waitUntilGone(confirm, timeout: 5))
        XCTAssertTrue(monday.exists, "Cancel keeps the note")
        monday.swipeLeft()
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(screen.empty.waitForExistence(timeout: 10), "The note is gone and the empty state is back")
        attach(name: "notes-emptied")
    }

    /// Collects a photo on the Library tab, then refers to it from the open note. The item stays in
    /// the Library whatever happens to the note.
    @MainActor
    private func linkALibraryItem(_ app: XCUIApplication, addReference: XCUIElement) throws {
        XCTAssertTrue(addReference.waitForExistence(timeout: 10), "A saved note offers Library items")
        addReference.tap()
        let pickerDone = app.buttons[Identifiers.Notes.Picker.done].firstMatch
        XCTAssertTrue(pickerDone.waitForExistence(timeout: 10), "The picker opens")
        attach(name: "notes-picker-empty")
        pickerDone.tap() // Nothing collected yet.

        tabButton(in: app, Identifiers.Tabs.library, title: "Library").tap()
        let add = app.buttons[ModuleIdentifiers.Attachments.add].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        app.buttons[ModuleIdentifiers.Attachments.addCamera].firstMatch.tap()
        let cells = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", ModuleIdentifiers.Attachments.itemPrefix))
        XCTAssertTrue(waitUntil(cells.firstMatch, "exists == true", timeout: 10), "The fake camera adds a photo to the Library")
        tabButton(in: app, Identifiers.Tabs.notes, title: "Notes").tap()

        XCTAssertTrue(addReference.waitForExistence(timeout: 10), "The editor is where it was")
        addReference.tap()
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Notes.Picker.itemPrefix)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10), "The collected photo is offered")
        item.tap()
        XCTAssertTrue(waitUntilGone(pickerDone, timeout: 10), "Picking closes the picker")
        attach(name: "notes-after-pick")
        let references = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Notes.Editor.referencePrefix))
        XCTAssertTrue(waitUntil(references.firstMatch, "exists == true", timeout: 10), "The note lists the item")
        attach(name: "notes-reference")
        addReference.tap()
        XCTAssertTrue(pickerDone.waitForExistence(timeout: 10))
        XCTAssertFalse(item.exists, "An item already referred to isn't offered again")
        pickerDone.tap()
    }
}
