import XCTest

/// The Library tab: collect a photo (fake camera) and a link (offline metadata), open an item, rename
/// it, preview it, keep everything across a relaunch, search, and delete with the confirmation from
/// the detail and from a cell. The simulator has no camera and the Photos picker runs out of process,
/// so the fakes stand in; the phone covers the real pickers and Files. Two tests, each collecting what
/// it needs: as one, it took up to 255 s of XCTest's 300 s allowance on a loaded runner, and a test
/// cut off there gets no second attempt.
final class LibraryUITests: StarterUITestCase {
    // A named store and the launch's own attachments directory, emptied first and kept for a relaunch.
    private let scenario = UITestLaunch(tab: Identifiers.Tabs.library, store: "library",
                                        extra: ["-attachments.fakeCamera", "YES", "-attachments.fakeLink", "Training Plan"])

    /// The Library tab's elements the tests share.
    @MainActor
    private struct Screen {
        let app: XCUIApplication
        var empty: XCUIElement { app.descendants(matching: .any).matching(identifier: Identifiers.Library.empty).firstMatch }
        var add: XCUIElement { app.buttons[ModuleIdentifiers.Attachments.add].firstMatch }
        var items: XCUIElementQuery {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", ModuleIdentifiers.Attachments.itemPrefix))
        }
        var photo: XCUIElement { items.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch }
        var link: XCUIElement { items.matching(NSPredicate(format: "label CONTAINS 'Training Plan'")).firstMatch }
        var deleteConfirm: XCUIElement { app.buttons[Identifiers.Library.deleteConfirm].firstMatch }
    }

    /// Launches on an empty Library with a store of its own; skips without the modules it needs.
    @MainActor
    private func launchEmpty() throws -> Screen {
        let app = XCUIApplication()
        app.launch(scenario)
        let screen = Screen(app: app)
        let library = tabButton(in: app, Identifiers.Tabs.library, title: "Library")
        try requireModuleUI("TabShell", appeared: library.waitForExistence(timeout: 10), "no Library tab")
        try requireModuleUI("Attachments", appeared: screen.empty.waitForExistence(timeout: 10), "no empty Library")
        XCTAssertTrue(screen.add.waitForExistence(timeout: 10), "The Library offers an Add menu")
        return screen
    }

    /// Collects a photo with the fake camera and a link with the offline metadata.
    @MainActor
    private func collectPhotoAndLink(_ screen: Screen) {
        let app = screen.app
        screen.add.tap()
        app.buttons[ModuleIdentifiers.Attachments.addCamera].firstMatch.tap()
        XCTAssertTrue(waitUntil(screen.items.firstMatch, "exists == true", timeout: 10), "The fake camera adds a photo")
        // The default wait: on a loaded runner one snapshot has taken 4 s, so 5 s allowed a single check.
        XCTAssertTrue(waitUntilGone(screen.empty), "The empty state goes with the first item")
        screen.add.tap()
        app.buttons[ModuleIdentifiers.Attachments.addLink].firstMatch.tap()
        let linkField = app.textFields[ModuleIdentifiers.Attachments.linkField].firstMatch
        let field = linkField.exists ? linkField : app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Adding a link asks for the address")
        field.tap()
        field.typeText("www.example.com/plan")
        app.buttons[ModuleIdentifiers.Attachments.linkAdd].firstMatch.tap()
        XCTAssertTrue(waitUntil(screen.items.element(boundBy: 1), "exists == true", timeout: 10), "The link is listed")
        XCTAssertTrue(app.descendants(matching: .any)[ModuleIdentifiers.Attachments.linkPreview].waitForExistence(timeout: 10),
                      "A link gets its card from the cached metadata")
        XCTAssertTrue(screen.photo.exists && screen.link.exists, "Cells read as kind and title")
    }

    /// Collect a photo and a link, open the photo, rename it, preview it, and find everything, the
    /// new title included, after a relaunch into the same store.
    @MainActor
    func testLibraryCollectsRenamesPreviewsAndKeeps() throws {
        let screen = try launchEmpty()
        let app = screen.app
        attach(name: "library-empty")
        collectPhotoAndLink(screen)
        attach(name: "library-collected")

        screen.photo.tap()
        let title = app.textFields[Identifiers.Library.Detail.title].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Tapping a cell opens the item's detail")
        XCTAssertEqual(title.value as? String, "Capture", "The title starts as the attachment's name")
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap() // Cursor at the end.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        app.typeText(" drill\n") // Return puts the keyboard away, which otherwise covers the actions below.
        XCTAssertEqual(title.value as? String, "Capture drill")
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch, timeout: 5))
        XCTAssertTrue(app.buttons[Identifiers.Library.Detail.share].firstMatch.exists, "A stored file can be shared")
        XCTAssertFalse(element(app, Identifiers.Library.Detail.missing).exists, "Its original is present")
        attach(name: "library-detail")
        let preview = app.buttons[Identifiers.Library.Detail.preview].firstMatch
        XCTAssertTrue(scroll(app, to: preview))
        preview.tap()
        XCTAssertTrue(app.otherElements["QLPreviewControllerView"].firstMatch.waitForExistence(timeout: 10),
                      "Preview opens the file in Quick Look")
        attach(name: "library-preview")
        // Quick Look's close button hides its chrome instead of closing on the iOS 27 simulator, so the
        // relaunch below is what leaves the preview.

        app.terminate()
        app.launch(scenario.relaunch)
        XCTAssertTrue(waitUntil(screen.items.element(boundBy: 1), "exists == true", timeout: 10), "Both items survive a relaunch")
        let renamed = screen.items.matching(NSPredicate(format: "label CONTAINS 'Capture drill'")).firstMatch
        XCTAssertTrue(renamed.exists, "The cell shows the title the person typed")
    }

    /// Search narrows to the link, then to nothing; deleting asks first, from the detail (where
    /// cancelling keeps the item) and from a cell, and an emptied Library shows its empty state.
    @MainActor
    func testLibrarySearchesAndDeletes() throws {
        let screen = try launchEmpty()
        let app = screen.app
        collectPhotoAndLink(screen)
        let photo = screen.photo, link = screen.link

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "The Library is searchable")
        try focus(searchField, in: app) // A single tap didn't take focus on a loaded hosted runner.
        app.typeText("plan")
        XCTAssertTrue(waitUntil(photo, "exists == false", timeout: 10), "The photo doesn't match")
        XCTAssertTrue(link.exists, "The link matches by title and address")
        app.typeText("zzz")
        let noResults = element(app, Identifiers.Library.noResults)
        XCTAssertTrue(noResults.waitForExistence(timeout: 10), "No match shows the system's no-results state")
        attach(name: "library-no-results")
        // The button beside the field reads Close on iOS 27 and Cancel before it.
        let close = app.buttons["Close"].firstMatch
        (close.exists ? close : app.buttons["Cancel"].firstMatch).tap()
        XCTAssertTrue(waitUntil(photo, "exists == true", timeout: 10), "Closing the search shows everything again")

        // Delete from the detail: Cancel keeps it, Delete removes it.
        photo.tap()
        let delete = app.buttons[Identifiers.Library.Detail.delete].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        XCTAssertTrue(scroll(app, to: delete))
        delete.tap()
        let confirm = screen.deleteConfirm
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Deleting asks first")
        attach(name: "library-delete-confirmation")
        // iOS 27 shows the dialog as a popover without a Cancel button: a tap outside cancels.
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() } else { app.staticTexts["Kind"].firstMatch.tap() }
        XCTAssertTrue(waitUntilGone(confirm, timeout: 5))
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Cancel keeps the item and its screen")
        delete.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(waitUntil(photo, "exists == false", timeout: 10), "The item is gone")
        XCTAssertTrue(waitUntil(link, "exists == true", timeout: 10), "Back on the Library, the link remains")

        // Delete from a cell: Remove on a long press asks the same question.
        link.press(forDuration: 1)
        let remove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "A long press offers Remove")
        remove.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Remove on a cell asks too")
        confirm.tap()
        XCTAssertTrue(screen.empty.waitForExistence(timeout: 10), "An emptied Library shows its empty state again")
        attach(name: "library-emptied")
    }
}
