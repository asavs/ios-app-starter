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
        app.launchArguments += ["-onboarding.completedVersion", "0"]
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
