import XCTest

/// The shell: tabs and their restored selection, deep links, the theme in both appearances, and the
/// launch-time measurement (skipped by `scripts/test-ios.sh`; run it from Xcode).
final class StarterAppUITests: StarterUITestCase {
    /// Switch the host's actual destinations, then relaunch without a selection override.
    @MainActor
    func testTabShellSwitchesAndRestoresSelection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-tabs.selected", "welcome", "-onboarding.completedVersion", "99",
                               "-tips.testing", "hideAll"]
        app.launch()
        let welcome = tabButton(in: app, "welcome", title: "Welcome")
        try requireModuleUI("TabShell", appeared: welcome.waitForExistence(timeout: 10), "no Welcome tab")
        let settings = tabButton(in: app, "settings", title: "Settings")
        try requireModuleUI("Settings", appeared: settings.waitForExistence(timeout: 5), "no Settings tab")
        XCTAssertTrue(waitUntil(welcome, "isSelected == true"))
        XCTAssertEqual(welcome.label, "Welcome")
        XCTAssertEqual(settings.label, "Settings")
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
        attach(name: "tabs-welcome")

        settings.tap()
        XCTAssertTrue(waitUntil(settings, "isSelected == true"))
        XCTAssertTrue(element(app, "settings.appearance").waitForExistence(timeout: 10))
        attach(name: "tabs-settings")
        welcome.tap()
        XCTAssertTrue(waitUntil(welcome, "isSelected == true"))
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(waitUntil(settings, "isSelected == true"))

        app.terminate()
        // No tabs.selected argument: restore the value saved by the native tab selection.
        app.launchArguments = ["-onboarding.completedVersion", "99", "-tips.testing", "hideAll"]
        app.launch()
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(settings, "isSelected == true"), "Relaunch should restore Settings")
        XCTAssertTrue(element(app, "settings.appearance").waitForExistence(timeout: 5))
        attach(name: "tabs-restored")
        welcome.tap() // Leave other local runs at the welcome screen.
    }

    /// The app's own link selects a tab; a link with a route, query or unknown tab changes nothing.
    /// `open(_:)` relaunches the app with the URL and the same launch arguments, so each link starts from
    /// the pinned tab: this covers links that launch the app. Skips without TabShell or Settings.
    @MainActor
    func testDeepLinkSelectsTab() throws {
        let scheme = try XCTUnwrap(Bundle(for: Self.self).object(forInfoDictionaryKey: "StarterAppURLScheme") as? String,
                                   "project.yml should pass APP_URL_SCHEME to the UI tests")
        let app = XCUIApplication()
        let welcome = tabButton(in: app, "welcome", title: "Welcome")
        let settings = tabButton(in: app, "settings", title: "Settings")
        func open(_ link: String, from tab: String) throws {
            app.launchArguments = ["-tabs.selected", tab, "-onboarding.completedVersion", "99", "-tips.testing", "hideAll"]
            app.open(try XCTUnwrap(URL(string: link)))
            try requireModuleUI("TabShell", appeared: welcome.waitForExistence(timeout: 10), "no Welcome tab")
            try requireModuleUI("Settings", appeared: settings.waitForExistence(timeout: 5), "no Settings tab")
        }

        try open("\(scheme)://settings", from: "welcome")
        XCTAssertTrue(waitUntil(settings, "isSelected == true"), "The link should select Settings")
        XCTAssertTrue(element(app, "settings.appearance").waitForExistence(timeout: 10))
        attach(name: "deep-link-settings")

        // The first two would select Welcome if the app accepted them; the last names no tab.
        for ignored in ["\(scheme)://welcome/secrets", "\(scheme)://welcome?reset=tips", "\(scheme)://nowhere"] {
            try open(ignored, from: "settings")
            XCTAssertTrue(waitUntil(settings, "isSelected == true"), "The pinned tab should load")
            XCTAssertFalse(waitUntil(welcome, "isSelected == true", timeout: 3), "\(ignored) should change nothing")
        }

        try open("\(scheme)://welcome", from: "settings")
        XCTAssertTrue(waitUntil(welcome, "isSelected == true"), "The link should select Welcome")
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 5))
    }

    /// The Theme module's main path: the themed welcome card and primary button render in light and in
    /// dark appearance, with a screenshot of each. Dark is forced through the Settings module's stored
    /// appearance (`-settings.appearance dark`); without Settings only the light pass runs.
    @MainActor
    func testThemeRendersInLightAndDark() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-tabs.selected", "welcome", "-onboarding.completedVersion", "99", "-settings.appearance", "light",
                                "-tips.testing", "hideAll"]
        app.launch()
        let card = element(app, "welcome.card")
        try requireModuleUI("Theme", appeared: card.waitForExistence(timeout: 10), "no themed card on the welcome screen")
        let hasSettings = settingsButton(in: app).waitForExistence(timeout: 5) // The tab bar can land after the card.
        let light = try assertThemedWelcome(app, name: "theme-light")
        if hasSettings {
            XCTAssertGreaterThan(light, 0.5, "The light background should be bright, got luminance \(light)")
        }

        try requireModuleUI("Settings", appeared: hasSettings, "no settings button, so dark appearance cannot be forced")
        app.terminate()
        app.launchArguments = ["-tabs.selected", "welcome", "-onboarding.completedVersion", "99", "-settings.appearance", "dark",
                                "-tips.testing", "hideAll"]
        app.launch()
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The themed card should render in dark appearance")
        let dark = try assertThemedWelcome(app, name: "theme-dark")
        XCTAssertLessThan(dark, 0.5, "The dark background should be dark, got luminance \(dark)")
    }

    /// Asserts the card and (when Onboarding is enabled) the primary button are on screen, attaches a
    /// screenshot, and returns the luminance of the screen background below the content.
    @MainActor
    private func assertThemedWelcome(_ app: XCUIApplication, name: String) throws -> CGFloat {
        let card = element(app, "welcome.card")
        XCTAssertTrue(waitUntilHittable(card), "The themed card should be visible")
        XCTAssertTrue(app.staticTexts["Replace this screen in ContentView.swift."].isHittable, "The card should show its details")
        let replay = app.buttons["onboarding.replay"]
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
            let app = XCUIApplication()
            app.launchArguments += ["-tabs.selected", "welcome", "-onboarding.completedVersion", "99", "-tips.testing", "hideAll"] // Measure the app, not onboarding.
            app.launch()
        }
    }
}
