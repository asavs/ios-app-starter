import XCTest

/// The shell: tabs and their restored selection, deep links, the theme in both appearances, and the
/// launch-time measurement (skipped by `scripts/test-ios.sh`; run it from Xcode).
final class StarterAppUITests: StarterUITestCase {
    /// Switch the host's actual destinations, then relaunch without a selection override.
    @MainActor
    func testTabShellSwitchesAndRestoresSelection() throws {
        let app = XCUIApplication()
        let scenario = UITestLaunch.tab(Identifiers.Tabs.welcome)
        app.launch(scenario)
        let welcome = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        try requireModuleUI("TabShell", appeared: welcome.waitForExistence(timeout: 10), "no Home tab")
        let settings = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        try requireModuleUI("Settings", appeared: settings.waitForExistence(timeout: 5), "no Settings tab")
        XCTAssertTrue(waitUntil(welcome, "isSelected == true"))
        XCTAssertEqual(welcome.label, "Home", "The welcome tab reads Home; its identifier stays welcome")
        XCTAssertEqual(settings.label, "Settings")
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
        attach(name: "tabs-welcome")

        settings.tap()
        XCTAssertTrue(waitUntil(settings, "isSelected == true"))
        XCTAssertTrue(element(app, ModuleIdentifiers.Settings.appearance).waitForExistence(timeout: 10))
        attach(name: "tabs-settings")
        welcome.tap()
        XCTAssertTrue(waitUntil(welcome, "isSelected == true"))
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(waitUntil(settings, "isSelected == true"))

        app.terminate()
        // No pinned tab: restore the value saved by the native tab selection.
        var restored = scenario.relaunch
        restored.tab = nil
        app.launch(restored)
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(settings, "isSelected == true"), "Relaunch should restore Settings")
        XCTAssertTrue(element(app, ModuleIdentifiers.Settings.appearance).waitForExistence(timeout: 5))
        attach(name: "tabs-restored")
    }

    /// A person's choice of tabs: order follows the choice, a feature left out has no tab, and a deep
    /// link to that feature brings its tab back and keeps it there after a relaunch.
    @MainActor
    func testChosenTabsOrderHideAndRevealFeatures() throws {
        let scheme = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "StarterAppURLScheme") as? String,
                                   "project.yml should pass APP_URL_SCHEME to the UI tests")
        let app = XCUIApplication()
        var scenario = UITestLaunch.tab(Identifiers.Tabs.settings)
        scenario.tabs = [Identifiers.Tabs.settings, Identifiers.Tabs.welcome]
        app.launch(scenario)
        let settings = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        let home = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        let timer = tabButton(in: app, Identifiers.Tabs.timer, title: "Timer")
        try requireModuleUI("TabShell", appeared: settings.waitForExistence(timeout: 10), "no Settings tab")
        try requireModuleUI("Settings", appeared: settings.exists, "no Settings tab")
        XCTAssertTrue(home.waitForExistence(timeout: 5), "Home is chosen")
        XCTAssertFalse(timer.exists, "A feature left out of the choice has no tab")
        XCTAssertLessThan(settings.frame.minX, home.frame.minX, "Tabs follow the chosen order")
        XCTAssertTrue(waitUntil(settings, "isSelected == true"))
        attach(name: "tabs-chosen")

        // The link to the hidden feature reveals it. Without the Timer modules the app says the
        // feature isn't in this build instead; that path has no simulator lane yet.
        try requireModuleUI("SessionTimer", appeared: Self.enabledModules?.contains("SessionTimer") ?? true,
                            "Timer isn't in this build, so the link would show the unavailable alert")
        app.open(try XCTUnwrap(URL(string: "\(scheme)://timer")), in: scenario.relaunch)
        XCTAssertTrue(timer.waitForExistence(timeout: 10), "The link should reveal the Timer tab")
        XCTAssertTrue(waitUntil(timer, "isSelected == true"), "The link should select the revealed tab")
        XCTAssertGreaterThan(timer.frame.minX, home.frame.minX, "A revealed tab goes last")
        XCTAssertTrue(element(app, Identifiers.Timer.primary).waitForExistence(timeout: 10))
        attach(name: "tabs-revealed")

        app.terminate()
        // Neither the choice nor the selection pinned: both come from what the app stored.
        var restored = scenario.relaunch
        restored.tabs = nil
        restored.tab = nil
        app.launch(restored)
        XCTAssertTrue(timer.waitForExistence(timeout: 10), "The revealed tab stays chosen")
        XCTAssertTrue(waitUntil(timer, "isSelected == true"), "Relaunch restores the revealed tab")
        XCTAssertTrue(settings.exists && home.exists)
        XCTAssertLessThan(settings.frame.minX, home.frame.minX, "The chosen order survives a relaunch")
    }

    /// The app's own link selects a tab; a link with a route, query or unknown tab changes nothing.
    /// `open(_:in:)` relaunches the app with the URL into the scenario, so each link starts from the
    /// pinned tab: this covers links that launch the app. Skips without TabShell or Settings.
    @MainActor
    func testDeepLinkSelectsTab() throws {
        let scheme = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "StarterAppURLScheme") as? String,
                                   "project.yml should pass APP_URL_SCHEME to the UI tests")
        let app = XCUIApplication()
        let welcome = tabButton(in: app, Identifiers.Tabs.welcome, title: "Home")
        let settings = tabButton(in: app, Identifiers.Tabs.settings, title: "Settings")
        func open(_ link: String, from tab: String) throws {
            app.open(try XCTUnwrap(URL(string: link)), in: .tab(tab))
            try requireModuleUI("TabShell", appeared: welcome.waitForExistence(timeout: 10), "no Home tab")
            try requireModuleUI("Settings", appeared: settings.waitForExistence(timeout: 5), "no Settings tab")
        }

        try open("\(scheme)://settings", from: Identifiers.Tabs.welcome)
        XCTAssertTrue(waitUntil(settings, "isSelected == true"), "The link should select Settings")
        XCTAssertTrue(element(app, ModuleIdentifiers.Settings.appearance).waitForExistence(timeout: 10))
        attach(name: "deep-link-settings")

        // The first two would select Welcome if the app accepted them; the last names no tab.
        for ignored in ["\(scheme)://welcome/secrets", "\(scheme)://welcome?reset=tips", "\(scheme)://nowhere"] {
            try open(ignored, from: Identifiers.Tabs.settings)
            XCTAssertTrue(waitUntil(settings, "isSelected == true"), "The pinned tab should load")
            XCTAssertFalse(waitUntil(welcome, "isSelected == true", timeout: 3), "\(ignored) should change nothing")
        }

        try open("\(scheme)://welcome", from: Identifiers.Tabs.settings)
        XCTAssertTrue(waitUntil(welcome, "isSelected == true"), "The link should select Home")
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
    }

    /// The Theme module's main path: the themed welcome card and primary button render in light and in
    /// dark appearance, with a screenshot of each. Dark is forced through the Settings module's stored
    /// appearance (`-settings.appearance dark`); without Settings only the light pass runs.
    @MainActor
    func testThemeRendersInLightAndDark() throws {
        let app = XCUIApplication()
        func appearance(_ name: String) -> UITestLaunch {
            UITestLaunch(tab: Identifiers.Tabs.welcome, extra: ["-settings.appearance", name])
        }
        app.launch(appearance("light"))
        let card = element(app, Identifiers.Welcome.card)
        try requireModuleUI("Theme", appeared: card.waitForExistence(timeout: 10), "no themed card on the welcome screen")
        let hasSettings = settingsButton(in: app).waitForExistence(timeout: 5) // The tab bar can land after the card.
        let light = try assertThemedWelcome(app, name: "theme-light")
        if hasSettings {
            XCTAssertGreaterThan(light, 0.5, "The light background should be bright, got luminance \(light)")
        }

        try requireModuleUI("Settings", appeared: hasSettings, "no settings button, so dark appearance cannot be forced")
        app.terminate()
        app.launch(appearance("dark"))
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The themed card should render in dark appearance")
        let dark = try assertThemedWelcome(app, name: "theme-dark")
        XCTAssertLessThan(dark, 0.5, "The dark background should be dark, got luminance \(dark)")
    }

    /// Asserts the card and (when Onboarding is enabled) the primary button are on screen, attaches a
    /// screenshot, and returns the luminance of the screen background below the content.
    @MainActor
    private func assertThemedWelcome(_ app: XCUIApplication, name: String) throws -> CGFloat {
        let card = element(app, Identifiers.Welcome.card)
        XCTAssertTrue(waitUntilHittable(card), "The themed card should be visible")
        XCTAssertTrue(app.staticTexts["Replace this screen in ContentView.swift."].isHittable, "The card should show its details")
        let replay = app.buttons[Identifiers.Welcome.replayTour]
        if replay.exists {
            XCTAssertTrue(replay.isHittable, "The primary-styled button should be visible")
        }
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Above the bottom edge, where a tab bar's material would be sampled instead of the background.
        return try luminance(of: screenshot.image, atNormalized: CGPoint(x: 0.5, y: 0.85))
    }

    /// Relative luminance (0 dark to 1 bright) of one pixel, given as a fraction of the image size.
    private func luminance(of image: UIImage, atNormalized point: CGPoint) throws -> CGFloat {
        let cgImage = try XCTUnwrap(image.cgImage, "Screenshot should have image data")
        let x = Int(CGFloat(cgImage.width) * point.x)
        let y = Int(CGFloat(cgImage.height) * point.y)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: -x, y: -(cgImage.height - 1 - y), width: cgImage.width, height: cgImage.height))
        return (0.299 * CGFloat(pixel[0]) + 0.587 * CGFloat(pixel[1]) + 0.114 * CGFloat(pixel[2])) / 255
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch(.tab(Identifiers.Tabs.welcome)) // Measure the app, not onboarding.
        }
    }
}
