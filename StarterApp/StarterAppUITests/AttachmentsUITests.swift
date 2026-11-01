import XCTest

/// The Attachments module on a preset: add a photo (fake camera), a link (offline metadata) and a
/// file, preview, remove, and keep them across a relaunch. The simulator has no camera and the
/// Photos picker runs out of process, so the fakes stand in; the phone covers the real ones.
final class AttachmentsUITests: StarterUITestCase {
    @MainActor
    func testPresetAttachments() throws {
        let app = XCUIApplication()
        let root = FileManager.default.temporaryDirectory.appending(path: "uitest-attachments").path()
        let arguments = ["-tabs.selected", "timer", "-onboarding.completedVersion", "99", "-tips.testing", "hideAll",
                         "-database.store", "uitest-attachments", "-attachments.root", root,
                         "-attachments.fakeCamera", "-attachments.fakeLink", "Fake Link Title"]
        app.launchArguments = arguments + ["-database.reset", "-attachments.reset"]
        app.launch()
        let ring = element(app, "timer.ring")
        try requireModuleUI("SessionTimer", appeared: ring.waitForExistence(timeout: 10), "no timer ring on the Timer tab")
        let presets = app.buttons["timer.presets"]
        try requireModuleUI("Database", appeared: presets.waitForExistence(timeout: 5), "no Presets button on the Timer tab")
        presets.tap()
        let tabata = app.buttons["timer.presets.row.Tabata"]
        XCTAssertTrue(tabata.waitForExistence(timeout: 10), "The seeded presets should be listed")
        tabata.swipeRight()
        let open = app.buttons["timer.presets.row.Tabata.attachments"]
        try requireModuleUI("Attachments", appeared: open.waitForExistence(timeout: 5), "no Attachments swipe action on a preset")
        open.tap()

        let add = app.buttons["attachments.add"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The Attachments screen should offer an Add menu")
        attach(name: "attachments-empty")

        add.tap()
        app.buttons["attachments.add.camera"].firstMatch.tap()
        let items = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'attachments.item.'"))
        XCTAssertTrue(waitUntil(items.firstMatch, "exists == true", timeout: 10), "The fake camera should add a photo")
        XCTAssertTrue(items.firstMatch.label.hasPrefix("Photo"), "The cell describes its kind, got: \(items.firstMatch.label)")

        add.tap()
        app.buttons["attachments.add.link"].firstMatch.tap()
        let field = app.textFields["attachments.link.field"].firstMatch.exists ? app.textFields["attachments.link.field"].firstMatch
            : app.alerts.firstMatch.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Adding a link should ask for the address")
        field.tap()
        field.typeText("www.example.com/plan")
        app.buttons["attachments.link.add"].firstMatch.tap()
        XCTAssertTrue(waitUntil(items.element(boundBy: 1), "exists == true", timeout: 10), "The link should be listed")
        XCTAssertTrue(app.descendants(matching: .any)["attachments.linkPreview"].waitForExistence(timeout: 10),
                      "A link gets its preview card from the cached metadata")
        attach(name: "attachments-photo-and-link")

        // Preview the photo in Quick Look. Its view covers the screen while the screen underneath stays
        // in the accessibility hierarchy, so its own view is what proves it opened.
        let photo = items.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch
        XCTAssertTrue(photo.exists, "The photo cell should be identifiable by its description")
        photo.tap()
        let quickLook = app.otherElements["QLPreviewControllerView"].firstMatch
        XCTAssertTrue(quickLook.waitForExistence(timeout: 10), "Tapping a file should open Quick Look")
        attach(name: "attachments-preview")
        // Quick Look's close button hides its chrome instead of closing on the iOS 27 simulator, so the
        // relaunch below is what leaves the preview; dismissal is Quick Look's own behaviour.

        // Everything survives a relaunch into the same store.
        app.terminate()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(presets.waitForExistence(timeout: 10))
        presets.tap()
        XCTAssertTrue(tabata.waitForExistence(timeout: 10))
        tabata.swipeRight()
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        XCTAssertTrue(waitUntil(items.element(boundBy: 1), "exists == true", timeout: 10), "Attachments should survive a relaunch")

        // Remove the photo through the context menu (the accessibility action is its twin).
        photo.press(forDuration: 1)
        let remove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "A long press should offer Remove")
        remove.tap()
        XCTAssertTrue(waitUntil(items.element(boundBy: 1), "exists == false", timeout: 10), "Removing should drop one item")
        attach(name: "attachments-after-remove")
        app.buttons["timer.presets.attachments.done"].tap()
    }
}
