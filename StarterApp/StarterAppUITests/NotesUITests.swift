import XCTest

/// The Notes tab: write and save a note, keep an unsaved draft across a tab switch, search, edit,
/// relaunch, refer to a Library item (with Attachments), and delete with the confirmation.
final class NotesUITests: StarterUITestCase {
    @MainActor
    func testNotesWriteSearchEditLinkAndDelete() throws {
        let app = XCUIApplication()
        let scenario = UITestLaunch(tab: Identifiers.Tabs.notes, store: "notes",
                                    extra: ["-attachments.fakeCamera", "YES", "-attachments.fakeLink", "Training Plan"])
        app.launch(scenario)
        let notesTab = tabButton(in: app, Identifiers.Tabs.notes, title: "Notes")
        try requireModuleUI("TabShell", appeared: notesTab.waitForExistence(timeout: 10), "no Notes tab")
        let empty = element(app, Identifiers.Notes.empty)
        try requireModuleUI("Database", appeared: empty.waitForExistence(timeout: 10), "no empty Notes state")
        attach(name: "notes-empty")

        // Write a note and save it; Save keeps the editor open, Done leaves.
        app.buttons[Identifiers.Notes.add].firstMatch.tap()
        let title = app.textFields[Identifiers.Notes.Editor.title].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Add opens an empty editor")
        let save = app.buttons[Identifiers.Notes.Editor.save].firstMatch
        XCTAssertFalse(save.isEnabled, "Nothing to save yet")
        try focus(title, in: app)
        app.typeText("Monday\n") // Return puts the keyboard away, so focusing the body below waits for it to come back.
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        let body = app.textViews[Identifiers.Notes.Editor.body].firstMatch
        try focus(body, in: app)
        app.typeText("Three rounds, then rest.")
        XCTAssertTrue(waitUntil(save, "isEnabled == true", timeout: 15), "Typing enables Save")
        attach(name: "notes-editor")
        save.tap()
        XCTAssertTrue(waitUntil(save, "isEnabled == false", timeout: 10), "Saved: nothing left to save")
        app.buttons[Identifiers.Notes.Editor.done].firstMatch.tap()
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Notes.rowPrefix))
        let monday = rows.matching(NSPredicate(format: "label CONTAINS 'Monday'")).firstMatch
        XCTAssertTrue(monday.waitForExistence(timeout: 10), "The saved note is listed")
        XCTAssertTrue(waitUntilGone(empty, timeout: 5))

        // A second note typed but not saved survives switching tabs, and is listed as unsaved.
        app.buttons[Identifiers.Notes.add].firstMatch.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        try focus(title, in: app)
        app.typeText("Shopping\n") // Return puts the keyboard away; it covers the tab bar otherwise.
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        home.tap()
        XCTAssertTrue(waitUntil(home, "isSelected == true"))
        notesTab.tap()
        XCTAssertTrue(waitUntil(notesTab, "isSelected == true"))
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The editor is where it was")
        XCTAssertEqual(title.value as? String, "Shopping", "With the draft")
        let done = app.buttons[Identifiers.Notes.Editor.done].firstMatch
        done.tap()
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
        XCTAssertTrue(title.exists, "Keep Editing stays")
        done.tap()
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 10), "Discard leaves the list as it was")
        XCTAssertFalse(rows.matching(NSPredicate(format: "label CONTAINS 'Shopping'")).firstMatch.exists, "The discarded draft is gone")

        // Search by body text, then no results.
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
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        try focus(body, in: app)
        app.typeText(" Stretch after.")
        XCTAssertTrue(waitUntil(save, "isEnabled == true", timeout: 15))
        save.tap()
        XCTAssertTrue(waitUntil(save, "isEnabled == false", timeout: 10))
        try focus(title, in: app)
        app.typeText("\n") // Return in the title puts the keyboard away; it covers the rows below.
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        let addReference = app.buttons[Identifiers.Notes.Editor.addReference].firstMatch
        if Self.enabledModules?.contains("Attachments") ?? addReference.exists {
            try linkALibraryItem(app, addReference: addReference)
        }
        done.tap()

        // Everything survives a relaunch into the same store.
        app.terminate()
        app.launch(scenario.relaunch)
        XCTAssertTrue(monday.waitForExistence(timeout: 10), "The note survives a relaunch")
        monday.tap()
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        let text = body.value as? String ?? ""
        XCTAssertTrue(text.contains("Three rounds, then rest.") && text.contains("Stretch after."), "With its edited text, got: \(text)")
        if addReference.exists {
            let references = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Notes.Editor.referencePrefix))
            XCTAssertTrue(references.firstMatch.waitForExistence(timeout: 10), "And its Library item")
        }
        done.tap()

        // Delete with the confirmation: Cancel keeps it, Delete removes it.
        XCTAssertTrue(monday.waitForExistence(timeout: 10))
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
        XCTAssertTrue(empty.waitForExistence(timeout: 10), "The note is gone and the empty state is back")
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
