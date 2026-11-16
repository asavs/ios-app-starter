import XCTest

/// The Images tab: pick a photo and take one (the fake Photos picker and camera, since the simulator
/// has no camera and the real picker runs out of process), see both in the grid, open one full
/// screen, swipe to the other, open its details, and delete from the viewer until nothing is left.
/// The phone covers the real pickers. Skips without TabShell or the Library's modules.
final class ImagesUITests: StarterUITestCase {
    private let scenario = UITestLaunch(tab: Identifiers.Tabs.images,
                                        tabs: [Identifiers.Tabs.welcome, Identifiers.Tabs.images, Identifiers.Tabs.settings],
                                        store: "images",
                                        extra: ["-attachments.fakeCamera", "YES", "-attachments.fakePhotos", "YES"])

    @MainActor
    func testPickViewSwipeAndDelete() throws {
        let app = XCUIApplication()
        app.launch(scenario)
        let tab = tabButton(in: app, Identifiers.Tabs.images, title: "Images")
        try requireModuleUI("TabShell", appeared: tab.waitForExistence(timeout: 10), "no Images tab")
        let empty = element(app, Identifiers.Images.empty)
        try requireModuleUI("Attachments", appeared: empty.waitForExistence(timeout: 10), "no empty Images tab")
        attach(name: "images-empty")

        // Add offers photos and the camera, nothing else.
        let add = app.buttons[ModuleIdentifiers.Attachments.add].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The tab offers an Add menu")
        add.tap()
        let photos = app.buttons[ModuleIdentifiers.Attachments.addPhotos].firstMatch
        XCTAssertTrue(photos.waitForExistence(timeout: 5), "Add offers Photos")
        XCTAssertTrue(app.buttons[ModuleIdentifiers.Attachments.addCamera].exists, "Add offers the camera")
        XCTAssertFalse(app.buttons[ModuleIdentifiers.Attachments.addFiles].exists, "No Files in an image picker")
        XCTAssertFalse(app.buttons[ModuleIdentifiers.Attachments.addLink].exists, "No links in an image picker")
        attach(name: "images-add-menu")
        photos.tap()
        let cells = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", ModuleIdentifiers.Attachments.itemPrefix))
        XCTAssertTrue(waitUntil(cells.firstMatch, "exists == true", timeout: 10), "The picked photo is listed")
        XCTAssertTrue(waitUntilGone(empty), "The empty state goes with the first photo")
        add.tap()
        app.buttons[ModuleIdentifiers.Attachments.addCamera].firstMatch.tap()
        XCTAssertTrue(waitUntil(cells.element(boundBy: 1), "exists == true", timeout: 10), "The capture is listed")
        attach(name: "images-grid")

        // Newest first: the capture opens, and a swipe shows the picked photo.
        let capture = cells.matching(NSPredicate(format: "label CONTAINS 'Capture'")).firstMatch
        capture.tap()
        let captureTitle = app.navigationBars.staticTexts["Capture"].firstMatch
        XCTAssertTrue(captureTitle.waitForExistence(timeout: 10), "A tap opens the photo full screen")
        let pages = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", Identifiers.Images.pagePrefix))
        XCTAssertTrue(pages.firstMatch.waitForExistence(timeout: 10), "The viewer shows a page")
        XCTAssertTrue(app.buttons[Identifiers.Images.share].firstMatch.exists, "The original can be shared")
        XCTAssertFalse(tab.isHittable, "The tab bar steps aside in the viewer")
        attach(name: "images-viewer")
        let photoTitle = app.navigationBars.staticTexts["Photo"].firstMatch
        XCTAssertTrue(perform({ app.swipeLeft() }, until: { photoTitle.exists }, retryingIf: { captureTitle.exists }),
                      "A swipe shows the next photo")

        // Details is the Library's screen for the same item.
        app.buttons[Identifiers.Images.details].firstMatch.tap()
        let title = app.textFields[Identifiers.Library.Detail.title].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Details opens the item's Library detail")
        XCTAssertEqual(title.value as? String, "Photo")
        app.navigationBars.buttons.firstMatch.tap() // Back to the viewer.
        XCTAssertTrue(photoTitle.waitForExistence(timeout: 10))

        // Deleting moves to the neighbor, and the last delete closes the viewer.
        try delete(in: app)
        XCTAssertTrue(captureTitle.waitForExistence(timeout: 10), "After a delete the viewer shows the photo beside it")
        try delete(in: app)
        // The viewer's close is a navigation pop; on a loaded runner the snapshot taken mid-pop can
        // time out, so wait for the pages to go before looking for the empty tab.
        XCTAssertTrue(waitUntilGone(pages.firstMatch, timeout: 20), "Deleting the last photo closes the viewer")
        XCTAssertTrue(waitUntil(empty, "exists == true", timeout: 20), "The viewer closes on an empty tab")
        attach(name: "images-emptied")
    }

    /// Delete from the viewer's bottom bar and confirm.
    @MainActor
    private func delete(in app: XCUIApplication) throws {
        let delete = app.buttons[Identifiers.Images.delete].firstMatch
        XCTAssertTrue(waitUntilHittable(delete), "The viewer offers Delete")
        delete.tap()
        let confirm = app.buttons[Identifiers.Library.deleteConfirm].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Deleting asks first")
        confirm.tap()
        XCTAssertTrue(waitUntilGone(confirm, timeout: 5))
    }
}
