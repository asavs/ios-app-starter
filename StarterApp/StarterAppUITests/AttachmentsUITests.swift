import XCTest

/// The Attachments module on a preset: add a photo (fake camera) and a link (offline metadata),
/// preview, keep across a relaunch, and remove. The simulator has no camera and the Photos picker
/// runs out of process, so the fakes stand in; the phone covers the real ones. Two tests, each adding
/// what it needs: as one, it took up to 271 s of XCTest's 300 s allowance on a loaded runner, and a
/// test cut off there gets no second attempt.
final class AttachmentsUITests: StarterUITestCase {
    // A named store and the launch's own attachments directory, emptied first and kept for a relaunch.
    private let scenario = UITestLaunch(tab: Identifiers.Tabs.timer, store: "attachments",
                                        extra: ["-attachments.fakeCamera", "YES", "-attachments.fakeLink", "Fake Link Title"])

    /// The Attachments screen's elements the tests share.
    @MainActor
    private struct Screen {
        let app: XCUIApplication
        var add: XCUIElement { app.buttons[ModuleIdentifiers.Attachments.add].firstMatch }
        var items: XCUIElementQuery {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", ModuleIdentifiers.Attachments.itemPrefix))
        }
        var photo: XCUIElement { items.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch }
    }

    /// From the Timer tab, opens the Tabata preset's Attachments screen; skips without the modules it needs.
    @MainActor
    private func openAttachments(in app: XCUIApplication) throws -> Screen {
        let ring = element(app, Identifiers.Timer.ring)
        try requireModuleUI("SessionTimer", appeared: ring.waitForExistence(timeout: 10), "no timer ring on the Timer tab")
        let presets = app.buttons[Identifiers.Timer.presets]
        try requireModuleUI("Database", appeared: presets.waitForExistence(timeout: 10), "no Presets button on the Timer tab")
        presets.tap()
        let tabata = app.buttons[Identifiers.Timer.Presets.row("Tabata")]
        XCTAssertTrue(tabata.waitForExistence(timeout: 10), "The seeded presets should be listed")
        tabata.swipeRight()
        let open = app.buttons[Identifiers.Timer.Presets.attachments(of: "Tabata")]
        try requireModuleUI("Attachments", appeared: open.waitForExistence(timeout: 5), "no Attachments swipe action on a preset")
        open.tap()
        let screen = Screen(app: app)
        XCTAssertTrue(screen.add.waitForExistence(timeout: 10), "The Attachments screen should offer an Add menu")
        return screen
    }

    /// Adds a photo with the fake camera.
    @MainActor
    private func addPhoto(_ screen: Screen) {
        screen.add.tap()
        screen.app.buttons[ModuleIdentifiers.Attachments.addCamera].firstMatch.tap()
        XCTAssertTrue(waitUntil(screen.items.firstMatch, "exists == true", timeout: 10), "The fake camera should add a photo")
    }

    /// A photo and a link on a preset, the link's preview card, and the photo in Quick Look.
    @MainActor
    func testPresetAttachmentsAddAndPreview() throws {
        let app = XCUIApplication()
        app.launch(scenario)
        let screen = try openAttachments(in: app)
        attach(name: "attachments-empty")

        addPhoto(screen)
        XCTAssertTrue(screen.items.firstMatch.label.hasPrefix("Photo"),
                      "The cell describes its kind, got: \(screen.items.firstMatch.label)")

        screen.add.tap()
        app.buttons[ModuleIdentifiers.Attachments.addLink].firstMatch.tap()
        let linkField = app.textFields[ModuleIdentifiers.Attachments.linkField].firstMatch
        let field = linkField.exists ? linkField : app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Adding a link should ask for the address")
        field.tap()
        field.typeText("www.example.com/plan")
        app.buttons[ModuleIdentifiers.Attachments.linkAdd].firstMatch.tap()
        XCTAssertTrue(waitUntil(screen.items.element(boundBy: 1), "exists == true", timeout: 10), "The link should be listed")
        XCTAssertTrue(app.descendants(matching: .any)[ModuleIdentifiers.Attachments.linkPreview].waitForExistence(timeout: 10),
                      "A link gets its preview card from the cached metadata")
        attach(name: "attachments-photo-and-link")

        // Preview the photo in Quick Look. Its view covers the screen while the screen underneath stays
        // in the accessibility hierarchy, so its own view is what proves it opened.
        XCTAssertTrue(screen.photo.exists, "The photo cell should be identifiable by its description")
        screen.photo.tap()
        let quickLook = app.otherElements["QLPreviewControllerView"].firstMatch
        XCTAssertTrue(quickLook.waitForExistence(timeout: 10), "Tapping a file should open Quick Look")
        attach(name: "attachments-preview")
        // Quick Look's close button hides its chrome instead of closing on the iOS 27 simulator, so the
        // test ends inside the preview; dismissal is Quick Look's own behaviour.
    }

    /// A photo survives a relaunch into the same store and goes when removed.
    @MainActor
    func testPresetAttachmentsSurviveRelaunchAndRemove() throws {
        let app = XCUIApplication()
        app.launch(scenario)
        var screen = try openAttachments(in: app)
        addPhoto(screen)

        app.terminate()
        app.launch(scenario.relaunch)
        screen = try openAttachments(in: app)
        XCTAssertTrue(waitUntil(screen.photo, "exists == true", timeout: 10), "Attachments should survive a relaunch")

        // Remove the photo through the context menu (the accessibility action is its twin).
        screen.photo.press(forDuration: 1)
        let remove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "A long press should offer Remove")
        remove.tap()
        XCTAssertTrue(waitUntilGone(screen.items.firstMatch, timeout: 10), "Removing should leave no item")
        attach(name: "attachments-after-remove")
        app.buttons[Identifiers.Timer.Presets.attachmentsDone].tap()
    }
}
