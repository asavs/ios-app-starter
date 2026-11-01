import XCTest

/// The Settings module and the sections other modules add to it.
final class SettingsUITests: StarterUITestCase {
    /// The About rows open their screens, and Erase Local Data puts the stored appearance back to System.
    @MainActor
    func testSettingsAboutScreensAndReset() throws {
        let app = XCUIApplication()
        // No settings.appearance argument: an argument would outrank what the picker stores and the reset erases.
        app.launchArguments = ["-tabs.selected", "settings", "-onboarding.completedVersion", "99", "-tips.testing", "hideAll"]
        app.launch()
        let picker = app.descendants(matching: .any).matching(identifier: "settings.appearance").firstMatch
        try requireModuleUI("Settings", appeared: picker.waitForExistence(timeout: 10), "no appearance picker")
        picker.buttons["Dark"].tap()
        XCTAssertTrue(waitUntil(picker.buttons["Dark"], "isSelected == true"))

        let privacy = app.buttons["settings.privacy"]
        XCTAssertTrue(scroll(app, to: privacy), "The About section should link to Privacy and Data")
        privacy.tap()
        XCTAssertTrue(app.staticTexts["settings.privacy.summary"].waitForExistence(timeout: 5))
        attach(name: "settings-privacy")
        app.navigationBars.buttons.firstMatch.tap()

        let acknowledgements = app.buttons["settings.acknowledgements"]
        XCTAssertTrue(scroll(app, to: acknowledgements))
        acknowledgements.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'settings.acknowledgements.'"))
            .firstMatch.waitForExistence(timeout: 5), "The template credits the starter it came from")
        attach(name: "settings-acknowledgements")
        app.navigationBars.buttons.firstMatch.tap()

        let reset = app.buttons["settings.reset"]
        XCTAssertTrue(scroll(app, to: reset))
        reset.tap()
        // The identifier lands on the dialog's cell and the button inside it; either tap works.
        let confirm = app.buttons["settings.reset.confirm"].firstMatch
        let erase = confirm.waitForExistence(timeout: 3) ? confirm : app.buttons["Erase"].firstMatch
        XCTAssertTrue(erase.waitForExistence(timeout: 5), "Erase should ask for confirmation first")
        attach(name: "settings-reset-confirm")
        erase.tap()
        // Back up to the top of the form; `scroll` only goes down.
        let window = app.windows.firstMatch
        for _ in 0..<6 where !(picker.exists && window.frame.contains(picker.frame)) { app.swipeDown() }
        XCTAssertTrue(waitUntil(picker.buttons["System"], "isSelected == true"), "Erasing local data should forget the appearance choice")
    }

    /// The Cues section in Settings: turning Sounds off disables "Play in silent mode", and the
    /// choice survives a relaunch. Leaves Sounds on. Skips when the Cues module is disabled.
    @MainActor
    func testCueSettings() throws {
        let app = XCUIApplication()
        // No cues.* arguments: an argument would outrank what the toggles store.
        app.launchArguments = ["-tabs.selected", "settings", "-onboarding.completedVersion", "99",
                               "-tips.testing", "hideAll"]
        app.launch()
        // The module's settings sit one level down, behind the Sounds & Haptics row.
        let cuesRow = app.buttons["settings.cues"]
        try requireModuleUI("Cues", appeared: scroll(app, to: cuesRow), "no Sounds & Haptics row in Settings")
        cuesRow.tap()
        let sound = app.switches["cues.sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5), "The row should push the Sounds & Haptics screen")
        let silentMode = app.switches["cues.silentMode"]
        // A Toggle's identifier lands on a switch spanning the row, whose center is the label; tap
        // the switch inside it. The section sits near the floating tab bar, so keep it clear first.
        func flip(_ toggle: XCUIElement) {
            let before = toggle.value as? String ?? ""
            XCTAssertTrue(scroll(app, to: toggle))
            // The section sits near the floating tab bar; keep the row clear of it.
            if toggle.frame.maxY > app.windows.firstMatch.frame.maxY - 120 { app.swipeUp() }
            // Let the push or the swipe finish first: a tap mid-animation lands elsewhere, and a retry
            // after a slow tap would flip it back. Then tap the knob on the row's trailing edge by
            // coordinate; asking the inner switch whether it's hittable fails the test outright while
            // the list settles ("Activation point invalid"), as it did on the hosted runner.
            XCTAssertTrue(waitUntilSettled(toggle), "\(toggle) should stop moving")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertTrue(waitUntil(toggle, "value != '\(before)'", timeout: 10), "\(toggle) should flip")
        }
        if sound.value as? String == "0" { flip(sound) }
        XCTAssertTrue(waitUntil(sound, "value == '1'"))
        XCTAssertTrue(silentMode.isEnabled)

        flip(sound)
        XCTAssertTrue(waitUntil(sound, "value == '0'"))
        XCTAssertTrue(waitUntil(silentMode, "isEnabled == false"), "Silent mode only applies with sounds on")

        let haptics = app.switches["cues.haptics"]
        XCTAssertTrue(haptics.isEnabled, "Haptics don't depend on sounds")
        if haptics.value as? String == "0" { flip(haptics) }
        XCTAssertTrue(waitUntil(haptics, "value == '1'"))
        flip(haptics)
        XCTAssertTrue(waitUntil(haptics, "value == '0'"))
        attach(name: "cues-settings-off")
        app.terminate()
        app.launch()
        XCTAssertTrue(scroll(app, to: cuesRow))
        cuesRow.tap()
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        XCTAssertEqual(sound.value as? String, "0", "Sounds off should survive a relaunch")
        XCTAssertEqual(haptics.value as? String, "0", "Haptics off should survive a relaunch")
        flip(sound)
        XCTAssertTrue(waitUntil(sound, "value == '1'"))
        flip(haptics)
        XCTAssertTrue(waitUntil(haptics, "value == '1'"))
    }

    /// The Settings module's main path: open the screen, pick an appearance, store and clear a secret
    /// in the simulator's real Keychain. Skips when the module is disabled (no gear button).
    @MainActor
    func testSettingsScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-tabs.selected", "welcome", "-onboarding.completedVersion", "99", // Past any flow version: straight to the welcome screen.
                                "-tips.testing", "hideAll"] // No tip popover over the gear button.
        app.launch()

        let open = settingsButton(in: app)
        try requireModuleUI("Settings", appeared: open.waitForExistence(timeout: 10), "no settings button on the welcome screen")
        open.tap()

        let picker = app.descendants(matching: .any).matching(identifier: "settings.appearance").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Settings should show the appearance picker")
        picker.buttons["Dark"].tap()
        // The app can report idle before a tap's state change lands, so state is waited for, not read once.
        XCTAssertTrue(waitUntil(picker.buttons["Dark"], "isSelected == true"), "Picking Dark should select it")

        let key = "example.apiKey"
        let field = app.secureTextFields["settings.secure.\(key).field"]
        let status = app.staticTexts["settings.secure.\(key).status"]
        let clear = app.buttons["settings.secure.\(key).clear"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Settings should show the example secret row")
        // The row reads the Keychain off the main actor, so wait for that first answer.
        XCTAssertTrue(waitUntil(status, "NOT (label BEGINSWITH 'Checking')"), "The row should finish its first read")
        if clear.exists { clear.tap() } // A previous run on this simulator may have left a value.
        XCTAssertTrue(waitUntil(status, "label BEGINSWITH 'Not set'"), "Secret should start empty, got: \(status.label)")
        try focus(field, in: app)
        app.typeText("ui-test-secret")
        app.buttons["settings.secure.\(key).save"].tap()
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "Saving should store the secret and offer Clear")
        XCTAssertTrue(waitUntil(status, "label BEGINSWITH 'Stored'"),
                      "Status should report the stored secret, got: \(status.label)")

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "settings-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        clear.tap()
        XCTAssertTrue(waitUntil(status, "label BEGINSWITH 'Not set'"),
                      "Clearing should forget the secret, got: \(status.label)")
        XCTAssertTrue(waitUntilGone(clear), "Clear should disappear once nothing is stored")

        // Resetting the tour only takes effect on the next launch, so the button says so and turns inactive.
        let tourReset = app.buttons["settings.onboarding.reset"]
        if tourReset.exists {
            tourReset.tap()
            XCTAssertTrue(waitUntil(tourReset, "label CONTAINS 'shows on next launch' AND isEnabled == false"),
                          "The reset button should confirm, got: \(tourReset.label)")
        }
        picker.buttons["System"].tap() // Leave the simulator's stored appearance as it was.
        XCTAssertTrue(waitUntil(picker.buttons["System"], "isSelected == true"))
    }
}
