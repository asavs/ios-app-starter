import XCTest

/// The Settings module and the sections other modules add to it. Every test launches into its own
/// emptied defaults suite (`UITestLaunch`), so none has to put a setting back for the next.
final class SettingsUITests: StarterUITestCase {
    /// The About rows open their screens, and Erase Local Data puts the stored appearance back to System.
    @MainActor
    func testSettingsAboutScreensAndReset() throws {
        let app = XCUIApplication()
        // No settings.appearance argument: an argument would outrank what the picker stores and the reset erases.
        app.launch(.tab(Identifiers.Tabs.settings))
        let picker = element(app, ModuleIdentifiers.Settings.appearance)
        try requireModuleUI("Settings", appeared: picker.waitForExistence(timeout: 10), "no appearance picker")
        picker.buttons["Dark"].tap()
        XCTAssertTrue(waitUntil(picker.buttons["Dark"], "isSelected == true"))

        let privacy = app.buttons[ModuleIdentifiers.Settings.privacy]
        XCTAssertTrue(scroll(app, to: privacy), "The About section should link to Privacy and Data")
        privacy.tap()
        XCTAssertTrue(app.staticTexts[ModuleIdentifiers.Settings.privacySummary].waitForExistence(timeout: 5))
        attach(name: "settings-privacy")
        app.navigationBars.buttons.firstMatch.tap()

        let acknowledgements = app.buttons[ModuleIdentifiers.Settings.acknowledgements]
        XCTAssertTrue(scroll(app, to: acknowledgements))
        acknowledgements.tap()
        let credits = NSPredicate(format: "identifier BEGINSWITH %@", ModuleIdentifiers.Settings.acknowledgementPrefix)
        XCTAssertTrue(app.descendants(matching: .any).matching(credits).firstMatch.waitForExistence(timeout: 5),
                      "The template credits the starter it came from")
        attach(name: "settings-acknowledgements")
        app.navigationBars.buttons.firstMatch.tap()

        let reset = app.buttons[ModuleIdentifiers.Settings.reset]
        XCTAssertTrue(scroll(app, to: reset))
        reset.tap()
        // The identifier lands on the dialog's cell and the button inside it; either tap works.
        let confirm = app.buttons[ModuleIdentifiers.Settings.resetConfirm].firstMatch
        let erase = confirm.waitForExistence(timeout: 3) ? confirm : app.buttons["Erase"].firstMatch
        XCTAssertTrue(erase.waitForExistence(timeout: 5), "Erase should ask for confirmation first")
        attach(name: "settings-reset-confirm")
        erase.tap()
        // Back up to the top of the form; `scroll` only goes down.
        let window = app.windows.firstMatch
        for _ in 0..<6 where !(picker.exists && window.frame.contains(picker.frame)) { app.swipeDown() }
        XCTAssertTrue(waitUntil(picker.buttons["System"], "isSelected == true"), "Erasing local data should forget the appearance choice")
    }

    /// The test harness itself: a setting made under a scenario survives `relaunch` and is gone after a
    /// launch that resets, so every test starts from a fresh install without touching the data of a normal
    /// launch on this simulator. Skips when the Settings module is disabled.
    @MainActor
    func testScenarioKeepsDataUntilReset() throws {
        let app = XCUIApplication()
        let scenario = UITestLaunch.tab(Identifiers.Tabs.settings)
        app.launch(scenario)
        let picker = element(app, ModuleIdentifiers.Settings.appearance)
        try requireModuleUI("Settings", appeared: picker.waitForExistence(timeout: 10), "no appearance picker")
        XCTAssertTrue(waitUntil(picker.buttons["System"], "isSelected == true"), "A reset launch starts from the default")
        picker.buttons["Dark"].tap()
        XCTAssertTrue(waitUntil(picker.buttons["Dark"], "isSelected == true"))

        app.terminate()
        app.launch(scenario.relaunch)
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(picker.buttons["Dark"], "isSelected == true"), "A relaunch keeps the test's data")

        app.terminate()
        app.launch(scenario)
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(picker.buttons["System"], "isSelected == true"), "A reset launch empties the suite")
        attach(name: "scenario-reset")
    }

    /// The Cues section in Settings: turning Sounds off disables "Play in silent mode", and the
    /// choice survives a relaunch. Skips when the Cues module is disabled.
    @MainActor
    func testCueSettings() throws {
        let app = XCUIApplication()
        // No cues.* arguments: an argument would outrank what the toggles store.
        let scenario = UITestLaunch.tab(Identifiers.Tabs.settings)
        app.launch(scenario)
        // The module's settings sit one level down, behind the Sounds & Haptics row.
        let cuesRow = app.buttons[ModuleIdentifiers.Settings.cues]
        try requireModuleUI("Cues", appeared: scroll(app, to: cuesRow), "no Sounds & Haptics row in Settings")
        cuesRow.tap()
        let sound = app.switches[ModuleIdentifiers.Cues.sound]
        XCTAssertTrue(sound.waitForExistence(timeout: 5), "The row should push the Sounds & Haptics screen")
        let silentMode = app.switches[ModuleIdentifiers.Cues.silentMode]
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
        XCTAssertTrue(waitUntil(sound, "value == '1'"), "Sounds start on in a fresh suite")
        XCTAssertTrue(silentMode.isEnabled)

        flip(sound)
        XCTAssertTrue(waitUntil(sound, "value == '0'"))
        XCTAssertTrue(waitUntil(silentMode, "isEnabled == false"), "Silent mode only applies with sounds on")

        let haptics = app.switches[ModuleIdentifiers.Cues.haptics]
        XCTAssertTrue(haptics.isEnabled, "Haptics don't depend on sounds")
        XCTAssertTrue(waitUntil(haptics, "value == '1'"), "Haptics start on in a fresh suite")
        flip(haptics)
        XCTAssertTrue(waitUntil(haptics, "value == '0'"))
        attach(name: "cues-settings-off")
        app.terminate()
        app.launch(scenario.relaunch)
        XCTAssertTrue(scroll(app, to: cuesRow))
        cuesRow.tap()
        XCTAssertTrue(sound.waitForExistence(timeout: 5))
        XCTAssertEqual(sound.value as? String, "0", "Sounds off should survive a relaunch")
        XCTAssertEqual(haptics.value as? String, "0", "Haptics off should survive a relaunch")
    }

    /// The Settings module's main path: open the screen, pick an appearance, store and clear a secret
    /// in the simulator's real Keychain. Skips when the module is disabled (no gear button).
    @MainActor
    func testSettingsScreen() throws {
        let app = XCUIApplication()
        app.launch(.tab(Identifiers.Tabs.welcome))

        let open = settingsButton(in: app)
        try requireModuleUI("Settings", appeared: open.waitForExistence(timeout: 10), "no settings button on the welcome screen")
        open.tap()

        let picker = element(app, ModuleIdentifiers.Settings.appearance)
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Settings should show the appearance picker")
        picker.buttons["Dark"].tap()
        // The app can report idle before a tap's state change lands, so state is waited for, not read once.
        XCTAssertTrue(waitUntil(picker.buttons["Dark"], "isSelected == true"), "Picking Dark should select it")

        let key = Identifiers.Settings.exampleSecretKey
        let field = app.secureTextFields[ModuleIdentifiers.Settings.Secure.field(key)]
        let status = app.staticTexts[ModuleIdentifiers.Settings.Secure.status(key)]
        let clear = app.buttons[ModuleIdentifiers.Settings.Secure.clear(key)]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Settings should show the example secret row")
        // The row reads the Keychain off the main actor, so wait for that first answer.
        XCTAssertTrue(waitUntil(status, "NOT (label BEGINSWITH 'Checking')"), "The row should finish its first read")
        // The Keychain isn't part of the test suite: a previous run on this simulator may have left a value.
        if clear.exists { clear.tap() }
        XCTAssertTrue(waitUntil(status, "label BEGINSWITH 'Not set'"), "Secret should start empty, got: \(status.label)")
        try focus(field, in: app)
        app.typeText("ui-test-secret")
        app.buttons[ModuleIdentifiers.Settings.Secure.save(key)].tap()
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
        let tourReset = app.buttons[Identifiers.Settings.onboardingReset]
        if tourReset.exists {
            tourReset.tap()
            XCTAssertTrue(waitUntil(tourReset, "label CONTAINS 'shows on next launch' AND isEnabled == false"),
                          "The reset button should confirm, got: \(tourReset.label)")
        }
    }
}
