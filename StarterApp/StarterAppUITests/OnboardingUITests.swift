import XCTest

/// The Onboarding module and the welcome screen: the flow, its memory, the largest text size.
final class OnboardingUITests: StarterUITestCase {
    @MainActor
    func testWelcomeScreen() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        // Force the onboarding flow when the Onboarding module is enabled: UserDefaults reads this
        // launch argument ahead of the stored completion, so the smoke test covers a first launch.
        app.launchArguments += ["-tabs.selected", "welcome", "-onboarding.completedVersion", "0",
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
        let moduleVersion = app.staticTexts["welcome.modulesVersion"]
        if Self.enabledModules?.contains("TemplateVersion") == true || moduleVersion.exists {
            XCTAssertTrue(moduleVersion.waitForExistence(timeout: 10), "The enabled module should report its version")
            XCTAssertEqual(moduleVersion.label, "Modules 0.3.1", "The welcome screen should identify this module release")
        }
    }

    /// The Onboarding module's main path: welcome sheet, the choice step (multiple select, answer shown on the
    /// welcome screen), a tour card, the notifications primer against a fake requester, then the welcome
    /// screen with its first contextual tip. Skips when the module is disabled (no Continue button).
    @MainActor
    func testOnboardingSteps() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-tabs.selected", "welcome", "-onboarding.completedVersion", "0", "-onboarding.permissions", "granted",
                                "-tips.reset", "YES"] // Forget earlier runs' dismissals so the first tip shows.
        app.launch()

        let next = app.buttons["onboarding.next"]
        try requireModuleUI("Onboarding", appeared: next.waitForExistence(timeout: 10), "no Continue button on launch")
        let skip = app.buttons["onboarding.skip"]

        // The page style keeps neighbouring pages in the hierarchy, so existence alone proves nothing;
        // a step is on screen when one of its leaf elements is hittable. Not the `onboarding.step.<id>`
        // container: XCUITest hit-tests a container at its centre, which on the choice step is empty
        // scroll view, and on the iOS 27 runner that check stayed false with the step fully on screen.
        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.feature.phone")),
                      "The welcome sheet should be the first step")
        XCTAssertTrue(waitUntilHittable(skip), "Skip should be offered on the welcome sheet")
        attach(name: "onboarding-welcome")
        next.tap()

        let tool = app.buttons["onboarding.choice.build.tool"]
        let product = app.buttons["onboarding.choice.build.product"]
        XCTAssertTrue(waitUntilHittable(tool), "The choice step should follow the welcome sheet, its answers as buttons")
        tool.tap()
        product.tap()
        // The app can report idle before a tap's state change lands, so state is waited for, not read once.
        XCTAssertTrue(waitUntil(tool, "isSelected == true") && waitUntil(product, "isSelected == true"),
                      "A multiple choice keeps every picked answer")
        attach(name: "onboarding-choice")
        tool.tap()
        XCTAssertTrue(waitUntil(tool, "isSelected == false"), "Tapping a picked answer again clears it")
        XCTAssertTrue(waitUntilHittable(skip), "Skip should still be offered on a choice step")
        next.tap()

        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.page.tour")),
                      "The tour card should follow the choice step")
        XCTAssertTrue(waitUntilHittable(tool, expected: false), "The choice step should have moved off")
        attach(name: "onboarding-tour")
        next.tap()

        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.permission.notifications.footnote")),
                      "The notifications primer, with its footnote, should be the last step")
        XCTAssertTrue(waitUntilHittable(skip, expected: false), "A permission primer has exactly one button")
        XCTAssertEqual(next.label, "Continue", "The primer's button is Continue, never Allow")
        attach(name: "onboarding-permission")
        next.tap() // The fake requester grants without a system alert, and the flow finishes.

        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 10),
                      "Finishing onboarding should reveal the welcome screen")
        XCTAssertTrue(waitUntilGone(next), "The flow should be gone once finished") // It fades out first.
        let goals = app.staticTexts["welcome.buildGoals"]
        XCTAssertTrue(goals.waitForExistence(timeout: 5), "The welcome screen should show the choice step's answer")
        XCTAssertEqual(goals.label, "Building: A product to sell", "The host should receive the final answer")

        // Contextual tips follow onboarding one at a time: the inline Settings tip when that module sits
        // behind the gear, then, once it is closed, the tour tip as a popover on the replay button. A Settings
        // tab gets no tip.
        let tour = app.staticTexts["See the tour again"]
        if app.buttons["settings.open"].waitForExistence(timeout: 5) {
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

    /// The largest accessibility text size: onboarding pages scroll to content below the fold instead of
    /// truncating it, the welcome screen keeps its button reachable, and the Settings secret row moves its
    /// buttons under the field instead of squeezing them. Skips when the Onboarding module is disabled.
    @MainActor
    func testLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                                "-tabs.selected", "welcome", "-onboarding.completedVersion", "0", "-onboarding.permissions", "granted",
                                "-tips.testing", "hideAll"]
        app.launch()

        let next = app.buttons["onboarding.next"]
        try requireModuleUI("Onboarding", appeared: next.waitForExistence(timeout: 10), "no Continue button on launch")
        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.feature.phone")),
                      "The welcome sheet should start with its first row")
        attach(name: "large-welcome")
        XCTAssertTrue(scroll(app, to: element(app, "onboarding.feature.yours")),
                      "The welcome sheet should scroll to its last row")
        next.tap()

        attach(name: "large-choice")
        XCTAssertTrue(scroll(app, to: app.buttons["onboarding.choice.build.product"]),
                      "The choice step should follow and scroll to its last answer")
        next.tap()

        XCTAssertTrue(waitUntilOnScreen(app, element(app, "onboarding.page.tour")), "The tour card should follow")
        attach(name: "large-tour")
        next.tap()

        XCTAssertTrue(waitUntilOnScreen(app, element(app, "onboarding.page.notifications")), "The primer should follow")
        attach(name: "large-permission")
        XCTAssertTrue(scroll(app, to: element(app, "onboarding.permission.notifications.footnote")),
                      "The primer's footnote should be reachable by scrolling")
        next.tap()

        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 10), "The welcome screen should follow")
        XCTAssertTrue(scroll(app, to: app.buttons["onboarding.replay"]), "The tour button should be reachable")
        attach(name: "large-welcome-screen")

        let open = settingsButton(in: app)
        guard open.waitForExistence(timeout: 5) else { return } // Settings module disabled.
        open.tap()
        let key = "example.apiKey"
        let field = app.secureTextFields["settings.secure.\(key).field"]
        let save = app.buttons["settings.secure.\(key).save"]
        XCTAssertTrue(field.waitForExistence(timeout: 10) && save.waitForExistence(timeout: 5),
                      "Settings should show the example secret row")
        XCTAssertGreaterThanOrEqual(save.frame.minY, field.frame.maxY - 1,
                                    "At this size Save should sit under the field, not beside it")
        attach(name: "large-settings")
    }

    /// Onboarding is remembered: finish it once, relaunch without the override, and it must not show again.
    /// Skips when the module is disabled.
    @MainActor
    func testOnboardingNotShownAgainAfterCompletion() throws {
        let app = XCUIApplication()
        // The argument domain shadows the stored value but never replaces it, so the first launch is
        // forced to show the flow while completion still writes to the persistent defaults.
        app.launchArguments = ["-tabs.selected", "welcome", "-onboarding.completedVersion", "0", "-onboarding.permissions", "granted",
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
        // No onboarding override: the stored version decides. The tab is pinned because an earlier
        // test can leave Settings selected, which TabShell rightly restores.
        app.launchArguments = ["-tabs.selected", "welcome", "-onboarding.permissions", "granted",
                               "-tips.testing", "hideAll"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Hello, world!"].waitForExistence(timeout: 10),
                      "A relaunch after completion should open on the welcome screen")
        XCTAssertFalse(next.waitForExistence(timeout: 3), "A completed flow must not show again on relaunch")
        attach(name: "onboarding-relaunch")
    }

    /// First launch shows onboarding as a sheet; swiping it down skips it for good, like the Skip button.
    /// Skips when the module is disabled.
    @MainActor
    func testSwipingOnboardingAwaySkipsIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-tabs.selected", "welcome", "-onboarding.completedVersion", "0", "-onboarding.permissions", "granted",
                               "-tips.testing", "hideAll"]
        app.launch()
        let next = app.buttons["onboarding.next"]
        try requireModuleUI("Onboarding", appeared: next.waitForExistence(timeout: 10), "no Continue button on launch")
        XCTAssertTrue(waitUntilHittable(element(app, "onboarding.feature.phone")), "The welcome sheet should be showing")
        attach(name: "onboarding-sheet")
        let sheet = element(app, "onboarding.step.welcome")
        sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0)))
        XCTAssertTrue(waitUntilGone(next), "Swiping the sheet down should close onboarding")
        XCTAssertTrue(app.buttons["onboarding.replay"].waitForExistence(timeout: 5), "The welcome screen should be under it")

        app.terminate()
        app.launchArguments = ["-tabs.selected", "welcome", "-onboarding.permissions", "granted", "-tips.testing", "hideAll"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.replay"].waitForExistence(timeout: 10))
        XCTAssertFalse(next.waitForExistence(timeout: 3), "A flow swiped away must not show again")
    }
}
