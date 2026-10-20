//
//  StarterAppUITests.swift
//  StarterAppUITests
//
//

import XCTest

final class StarterAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testWelcomeScreen() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        // Force the onboarding flow when the Onboarding module is enabled: UserDefaults reads this
        // launch argument ahead of the stored completion, so the smoke test covers a first launch.
        app.launchArguments += ["-onboarding.completedVersion", "0",
                                "-onboarding.permissions", "granted", // No system alert on the primer.
                                "-tips.testing", "hideAll"] // No tip popover over the welcome screen.
        app.launch()

        // Step through onboarding when it appears; with the module disabled the welcome screen is first.
        let next = app.buttons["onboarding.next"]
        if next.waitForExistence(timeout: 5) {
            let onboarding = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            onboarding.name = "onboarding-first-page"
            onboarding.lifetime = .keepAlways
            add(onboarding)
            var taps = 0
            while next.exists, taps < 10 {
                next.tap()
                taps += 1
            }
            XCTAssertFalse(next.waitForExistence(timeout: 2), "Onboarding should finish after its last page")
        }

        let visible = app.staticTexts["Hello, world!"].waitForExistence(timeout: 10)

        // Always keep one screenshot so CI reports show the screen, pass or fail.
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "welcome-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(visible, "Welcome text should be visible")
    }

    /// The Onboarding module's main path: welcome sheet, the choice step (multiple select, answer shown on the
    /// welcome screen), a tour card, the notifications primer against a fake requester, then the welcome
    /// screen with its first contextual tip. Skips when the module is disabled (no Continue button).
    @MainActor
    func testOnboardingSteps() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-onboarding.completedVersion", "0", "-onboarding.permissions", "granted",
                                "-tips.reset", "YES"] // Forget earlier runs' dismissals so the first tip shows.
        app.launch()

        let next = app.buttons["onboarding.next"]
        try requireModuleUI("Onboarding", appeared: next.waitForExistence(timeout: 10), "no Continue button on launch")
        let skip = app.buttons["onboarding.skip"]

        // The page style keeps neighbouring pages in the hierarchy, so existence alone proves nothing;
        // a step is on screen when it is hittable.
        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.step.welcome")),
                      "The welcome sheet should be the first step")
        XCTAssertTrue(element(app, "onboarding.feature.Make it yours").isHittable, "Welcome rows should be visible")
        XCTAssertTrue(skip.isHittable, "Skip should be offered on the welcome sheet")
        attach(name: "onboarding-welcome")
        next.tap()

        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.step.build")),
                      "The choice step should follow the welcome sheet")
        let tool = app.buttons["onboarding.choice.build.A tool for myself"]
        let product = app.buttons["onboarding.choice.build.A product to sell"]
        XCTAssertTrue(tool.isHittable, "Each answer should be a button")
        tool.tap()
        product.tap()
        XCTAssertTrue(tool.isSelected && product.isSelected, "A multiple choice keeps every picked answer")
        attach(name: "onboarding-choice")
        tool.tap()
        XCTAssertFalse(tool.isSelected, "Tapping a picked answer again clears it")
        XCTAssertTrue(skip.isHittable, "Skip should still be offered on a choice step")
        next.tap()

        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.step.tour")),
                      "The tour card should follow the choice step")
        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.step.build"), expected: false),
                      "The choice step should have moved off")
        attach(name: "onboarding-tour")
        next.tap()

        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.step.notifications")),
                      "The notifications primer should be the last step")
        XCTAssertTrue(element(app, "onboarding.permission.notifications.footnote").isHittable,
                      "The primer should show its footnote")
        XCTAssertTrue(waitUntilHittable(skip, expected: false), "A permission primer has exactly one button")
        XCTAssertEqual(next.label, "Continue", "The primer's button is Continue, never Allow")
        attach(name: "onboarding-permission")
        next.tap() // The fake requester grants without a system alert, and the flow finishes.

        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 10),
                      "Finishing onboarding should reveal the welcome screen")
        XCTAssertFalse(next.exists, "The flow should be gone once finished")
        let goals = app.staticTexts["welcome.buildGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5), "The welcome screen should show the choice step's answer")
        XCTAssertEqual(goals.label, "Building: A product to sell", "The host should receive the final answer")

        // Contextual tips follow onboarding one at a time: the inline Settings tip when that module is
        // enabled, then, once it is closed, the tour tip as a popover on the replay button.
        let tour = app.staticTexts["See the tour again"]
        if app.buttons["settings.open"].exists {
            let settingsTip = app.staticTexts["Settings live here"]
            XCTAssertTrue(settingsTip.waitForExistence(timeout: 10), "The Settings tip should show after onboarding")
            XCTAssertFalse(tour.exists, "Tips show one at a time")
            attach(name: "onboarding-tip-settings")
            app.buttons["Close"].firstMatch.tap()
            XCTAssertTrue(waitUntilGone(settingsTip), "Closing a tip should remove it")
        }
        XCTAssertTrue(tour.waitForExistence(timeout: 10), "The tour tip should show next")
        attach(name: "onboarding-tip-tour")
    }

    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// Waits for the element to become hittable (or not), which outlasts the flow's short transitions.
    /// The limit is generous because on a loaded hosted runner one hierarchy snapshot of the paged flow
    /// has taken over 4 s, so a 5 s wait expired after a single check; a settled element returns at once.
    private func waitUntilHittable(_ element: XCUIElement, expected: Bool = true, timeout: TimeInterval = 15) -> Bool {
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == %@", NSNumber(value: expected)),
                                                object: element)
        return XCTWaiter().wait(for: [settled], timeout: timeout) == .completed
    }

    /// Any element with this accessibility identifier; containers and combined rows vary in type.
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func attach(name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Onboarding is remembered: finish it once, relaunch without the override, and it must not show again.
    /// Skips when the module is disabled.
    @MainActor
    func testOnboardingNotShownAgainAfterCompletion() throws {
        let app = XCUIApplication()
        // The argument domain shadows the stored value but never replaces it, so the first launch is
        // forced to show the flow while completion still writes to the persistent defaults.
        app.launchArguments = ["-onboarding.completedVersion", "0", "-onboarding.permissions", "granted",
                               "-tips.testing", "hideAll"]
        app.launch()
        let next = app.buttons["onboarding.next"]
        try requireModuleUI("Onboarding", appeared: next.waitForExistence(timeout: 10), "no Continue button on launch")
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(waitUntilHittable(skip), "Skip should be offered on the first step")
        skip.tap()
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 10),
                      "Skipping should reveal the welcome screen and record completion")

        app.terminate()
        app.launchArguments = ["-onboarding.permissions", "granted", // No override: the stored version decides.
                               "-tips.testing", "hideAll"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 10),
                      "A relaunch after completion should open on the welcome screen")
        XCTAssertFalse(next.waitForExistence(timeout: 3), "A completed flow must not show again on relaunch")
        attach(name: "onboarding-relaunch")
    }

    /// The Theme module's main path: the themed welcome card and primary button render in light and in
    /// dark appearance, with a screenshot of each. Dark is forced through the Settings module's stored
    /// appearance (`-settings.appearance dark`); without Settings only the light pass runs.
    @MainActor
    func testThemeRendersInLightAndDark() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding.completedVersion", "99", "-settings.appearance", "light",
                                "-tips.testing", "hideAll"]
        app.launch()
        let card = element(app, "welcome.card")
        try requireModuleUI("Theme", appeared: card.waitForExistence(timeout: 10), "no themed card on the welcome screen")
        let hasSettings = app.buttons["settings.open"].exists
        let light = try assertThemedWelcome(app, name: "theme-light")
        if hasSettings {
            XCTAssertGreaterThan(light, 0.5, "The light background should be bright, got luminance \(light)")
        }

        try requireModuleUI("Settings", appeared: hasSettings, "no settings button, so dark appearance cannot be forced")
        app.terminate()
        app.launchArguments = ["-onboarding.completedVersion", "99", "-settings.appearance", "dark",
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
        XCTAssertTrue(app.staticTexts["Built on GitHub Actions."].isHittable, "The card should show its details")
        let replay = app.buttons["onboarding.replay"]
        if replay.exists {
            XCTAssertTrue(replay.isHittable, "The primary-styled button should be visible")
        }
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return try luminance(of: screenshot.image, atNormalized: CGPoint(x: 0.5, y: 0.93))
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

    /// Gives a text field keyboard focus. On the iOS 27 simulator a single tap on a `SecureField` in a
    /// `Form` row sometimes selects the row without focusing the field, and `typeText` then fails with
    /// "Neither element nor any descendant has keyboard focus"; tapping again focuses it.
    private func focus(_ field: XCUIElement, attempts: Int = 4) throws {
        for attempt in 1...attempts {
            field.tap()
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
            if XCTWaiter().wait(for: [focused], timeout: 2) == .completed { return }
            XCTContext.runActivity(named: "Field not focused after tap \(attempt)") { _ in }
        }
        XCTFail("\(field.identifier) did not take keyboard focus after \(attempts) taps")
        throw ModuleUIMissing(description: "no keyboard focus on \(field.identifier)")
    }

    /// Modules the lane built the app with, from `scripts/test-ios.sh` (`TEST_RUNNER_IOS_ENABLED_MODULES`);
    /// `nil` when unknown, such as a run from Xcode.
    private static let enabledModules: Set<String>? = ProcessInfo.processInfo.environment["IOS_ENABLED_MODULES"]
        .map { Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }).filter { !$0.isEmpty } }

    private struct ModuleUIMissing: Error, CustomStringConvertible {
        let description: String
    }

    /// Skips the test when `module` is disabled in this build; fails it when the lane says the module is
    /// enabled but its UI did not appear, so a stale launch argument cannot hide behind a skip.
    private func requireModuleUI(_ module: String, appeared: Bool, _ detail: String) throws {
        guard !appeared else { return }
        if let enabled = Self.enabledModules, enabled.contains(module) {
            let message = "\(module) is enabled in this build but \(detail)"
            XCTFail(message)
            throw ModuleUIMissing(description: message)
        }
        throw XCTSkip("\(module) module disabled: \(detail)")
    }

    /// The Settings module's main path: open the screen, pick an appearance, store and clear a secret
    /// in the simulator's real Keychain. Skips when the module is disabled (no gear button).
    @MainActor
    func testSettingsScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-onboarding.completedVersion", "99", // Past any flow version: straight to the welcome screen.
                                "-tips.testing", "hideAll"] // No tip popover over the gear button.
        app.launch()

        let open = app.buttons["settings.open"]
        try requireModuleUI("Settings", appeared: open.waitForExistence(timeout: 10), "no settings button on the welcome screen")
        open.tap()

        let picker = app.descendants(matching: .any).matching(identifier: "settings.appearance").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Settings should show the appearance picker")
        picker.buttons["Dark"].tap()
        XCTAssertTrue(picker.buttons["Dark"].isSelected, "Picking Dark should select it")

        let key = "example.apiKey"
        let field = app.secureTextFields["settings.secure.\(key).field"]
        let status = app.staticTexts["settings.secure.\(key).status"]
        let clear = app.buttons["settings.secure.\(key).clear"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Settings should show the example secret row")
        if clear.exists { clear.tap() } // A previous run on this simulator may have left a value.
        XCTAssertTrue(status.label.hasPrefix("Not set"), "Secret should start empty, got: \(status.label)")
        try focus(field)
        field.typeText("ui-test-secret")
        app.buttons["settings.secure.\(key).save"].tap()
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "Saving should store the secret and offer Clear")
        XCTAssertTrue(status.label.hasPrefix("Stored"), "Status should report the stored secret, got: \(status.label)")

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "settings-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        clear.tap()
        XCTAssertTrue(status.label.hasPrefix("Not set"), "Clearing should forget the secret, got: \(status.label)")
        XCTAssertFalse(clear.exists, "Clear should disappear once nothing is stored")
        picker.buttons["System"].tap() // Leave the simulator's stored appearance as it was.
        XCTAssertTrue(picker.buttons["System"].isSelected)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments += ["-onboarding.completedVersion", "99", "-tips.testing", "hideAll"] // Measure the app, not onboarding.
            app.launch()
        }
    }
}
