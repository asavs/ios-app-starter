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
                                "-onboarding.permissions", "granted"] // No system alert on the primer.
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

    /// The Onboarding module's main path: welcome sheet, a tour card, the notifications primer against a
    /// fake requester, then the welcome screen. Skips when the module is disabled (no Continue button).
    @MainActor
    func testOnboardingSteps() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-onboarding.completedVersion", "0", "-onboarding.permissions", "granted"]
        app.launch()

        let next = app.buttons["onboarding.next"]
        guard next.waitForExistence(timeout: 10) else {
            throw XCTSkip("Onboarding module disabled: no Continue button on launch")
        }
        let skip = app.buttons["onboarding.skip"]

        // The page style keeps neighbouring pages in the hierarchy, so existence alone proves nothing;
        // a step is on screen when it is hittable.
        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.step.welcome")),
                      "The welcome sheet should be the first step")
        XCTAssertTrue(element(app, "onboarding.feature.Make it yours").isHittable, "Welcome rows should be visible")
        XCTAssertTrue(skip.isHittable, "Skip should be offered on the welcome sheet")
        attach(name: "onboarding-welcome")
        next.tap()

        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.step.tour")),
                      "The tour card should follow the welcome sheet")
        XCTAssertFalse(element(app, "onboarding.step.welcome").isHittable, "The welcome sheet should have moved off")
        XCTAssertTrue(skip.isHittable, "Skip should still be offered on a tour card")
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
    }

    /// Waits for the element to become hittable (or not), which outlasts the flow's short transitions.
    private func waitUntilHittable(_ element: XCUIElement, expected: Bool = true, timeout: TimeInterval = 5) -> Bool {
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

    /// The Settings module's main path: open the screen, pick an appearance, store and clear a secret
    /// in the simulator's real Keychain. Skips when the module is disabled (no gear button).
    @MainActor
    func testSettingsScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-onboarding.completedVersion", "1"] // Go straight to the welcome screen.
        app.launch()

        let open = app.buttons["settings.open"]
        guard open.waitForExistence(timeout: 10) else {
            throw XCTSkip("Settings module disabled: no settings button on the welcome screen")
        }
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
        field.tap()
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
            app.launchArguments += ["-onboarding.completedVersion", "1"] // Measure the app, not onboarding.
            app.launch()
        }
    }
}
