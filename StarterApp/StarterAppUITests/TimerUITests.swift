import XCTest

/// The Timer tab: running, editing and saving a plan, the largest text size, the Live Activity.
final class TimerUITests: StarterUITestCase {
    /// The Edit sheet: set the work phase to 0:30 with the hours, minutes and seconds wheels and add a round; the ring and
    /// step count follow, and the times survive a relaunch. Skips when DurationPicker is disabled.
    @MainActor
    func testTimerEditsAPlan() throws {
        let app = XCUIApplication()
        // No timer.* arguments: they would outrank what the editor stores.
        let scenario = UITestLaunch.tab(Identifiers.Tabs.timer)
        app.launch(scenario)
        let ring = element(app, Identifiers.Timer.ring)
        try requireModuleUI("SessionTimer", appeared: ring.waitForExistence(timeout: 10), "no timer ring on the Timer tab")
        let edit = app.buttons[Identifiers.Timer.edit]
        try requireModuleUI("DurationPicker", appeared: edit.waitForExistence(timeout: 5), "no Edit button on the Timer tab")
        element(app, Identifiers.Timer.plan).buttons["Intervals"].tap()
        edit.tap()

        let work = app.buttons[Identifiers.Timer.Edit.work]
        XCTAssertTrue(work.waitForExistence(timeout: 10))
        work.tap()
        // Hours, minutes and seconds, as in the Clock app.
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 2).waitForExistence(timeout: 5), "Tapping the row should show three wheels")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "0")
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "0")
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: "30")
        XCTAssertTrue(waitUntil(work, "value == '30 seconds'"), "The row should show the new length")
        let rounds = element(app, Identifiers.Timer.Edit.rounds)
        rounds.buttons.element(boundBy: 1).tap() // Increment.
        let roundCount = try XCTUnwrap(Int(try XCTUnwrap(rounds.label.split(separator: " ").last)))
        attach(name: "timer-edit")
        app.buttons[Identifiers.Timer.Edit.done].tap()

        XCTAssertTrue(waitUntil(ring, "value == '30 seconds remaining'"))
        let step = element(app, Identifiers.Timer.step)
        XCTAssertEqual(step.label, "Step 1 of \(2 * roundCount - 1)")
        app.terminate()
        app.launch(scenario.relaunch)
        XCTAssertTrue(ring.waitForExistence(timeout: 10))
        XCTAssertEqual(ring.value as? String, "30 seconds remaining", "Edited times should survive a relaunch")
    }

    /// Presets come from the database: the seeded ones show, a saved one survives a relaunch, loading one
    /// sets the ring, and a swipe deletes. Skips when the Database or timer modules are disabled.
    @MainActor
    func testTimerPresets() throws {
        let app = XCUIApplication()
        // A named store, emptied on the first launch and kept for the second.
        let scenario = UITestLaunch(tab: Identifiers.Tabs.timer, store: "presets")
        app.launch(scenario)
        let ring = element(app, Identifiers.Timer.ring)
        try requireModuleUI("SessionTimer", appeared: ring.waitForExistence(timeout: 10), "no timer ring on the Timer tab")
        let presets = app.buttons[Identifiers.Timer.presets]
        try requireModuleUI("Database", appeared: presets.waitForExistence(timeout: 5), "no Presets button on the Timer tab")
        presets.tap()
        let tabata = app.buttons[Identifiers.Timer.Presets.row("Tabata")]
        XCTAssertTrue(tabata.waitForExistence(timeout: 10), "The seeded presets should be listed")

        app.buttons[Identifiers.Timer.Presets.save].tap()
        // An alert's text field doesn't carry an accessibility identifier; find it through the alert.
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Save Current should ask for a name")
        let name = alert.textFields.firstMatch
        name.tap()
        name.typeText("Mine")
        alert.buttons["Save"].tap()
        let mine = app.buttons[Identifiers.Timer.Presets.row("Mine")]
        XCTAssertTrue(mine.waitForExistence(timeout: 5), "The saved preset should appear")
        attach(name: "timer-presets")
        app.buttons[Identifiers.Timer.Presets.done].tap()

        app.terminate()
        app.launch(scenario.relaunch)
        XCTAssertTrue(presets.waitForExistence(timeout: 10))
        presets.tap()
        XCTAssertTrue(mine.waitForExistence(timeout: 10), "A saved preset should survive a relaunch")
        tabata.tap()
        XCTAssertTrue(waitUntil(ring, "value == '20 seconds remaining'"), "Loading Tabata should set a 20-second work phase")
        attach(name: "timer-preset-loaded")

        presets.tap()
        XCTAssertTrue(mine.waitForExistence(timeout: 10))
        mine.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(waitUntilGone(mine), "Swiping should delete the preset")
        app.buttons[Identifiers.Timer.Presets.done].tap()
    }

    /// At the largest accessibility text size the Timer tab scrolls to its controls and stacks Skip
    /// above Reset rather than wrapping their labels. Skips when the timer modules are disabled.
    @MainActor
    func testTimerAtLargestTextSize() throws {
        let app = XCUIApplication()
        app.launch(UITestLaunch(tab: Identifiers.Tabs.timer, extra: UITestLaunch.largestTextSize))
        let ring = element(app, Identifiers.Timer.ring)
        try requireModuleUI("SessionTimer", appeared: ring.waitForExistence(timeout: 10), "no timer ring on the Timer tab")
        attach(name: "timer-large-ring")
        let skip = element(app, Identifiers.Timer.skip)
        let reset = element(app, Identifiers.Timer.reset)
        XCTAssertTrue(scroll(app, to: reset), "The Timer tab should scroll to Reset")
        XCTAssertLessThan(skip.frame.maxY, reset.frame.minY, "Skip should sit above Reset at this size")
        attach(name: "timer-large-controls")
    }

    /// The Timer tab's main path: run the interval plan, pause, skip through every phase to done,
    /// reset, then switch to the focus plan. Skips when the timer modules are disabled.
    @MainActor
    func testTimerRunsAPlan() throws {
        let app = XCUIApplication()
        // The plans' times, pinned so the assertions read the same whatever the template's defaults become.
        app.launch(UITestLaunch(tab: Identifiers.Tabs.timer,
                                extra: ["-timer.intervals", "20,10,3", "-timer.focus", "1500,300,4"]))
        let ring = element(app, Identifiers.Timer.ring)
        try requireModuleUI("SessionTimer", appeared: ring.waitForExistence(timeout: 10), "no timer ring on the Timer tab")
        let primary = element(app, Identifiers.Timer.primary)
        let skip = element(app, Identifiers.Timer.skip)
        let reset = element(app, Identifiers.Timer.reset)
        let step = element(app, Identifiers.Timer.step)
        XCTAssertEqual(ring.label, "Work")
        XCTAssertEqual(ring.value as? String, "20 seconds remaining")
        XCTAssertEqual(step.label, "Step 1 of 5")
        XCTAssertEqual(primary.label, "Start")
        XCTAssertFalse(skip.isEnabled)
        XCTAssertFalse(reset.isEnabled)

        primary.tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Pause'"))
        XCTAssertTrue(waitUntil(ring, "value != '20 seconds remaining'", timeout: 10), "The countdown should run")
        attach(name: "timer-running")

        primary.tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Resume'"))
        let paused = ring.value as? String
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(ring.value as? String, paused, "A paused countdown should not move")

        primary.tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Pause'"))
        skip.tap()
        XCTAssertTrue(waitUntil(step, "label == 'Step 2 of 5'"))
        XCTAssertEqual(ring.label, "Rest")
        for next in 3...5 {
            skip.tap()
            XCTAssertTrue(waitUntil(step, "label == 'Step \(next) of 5'"))
        }
        XCTAssertEqual(ring.label, "Work")
        skip.tap()
        XCTAssertTrue(waitUntil(ring, "label == 'Done'"))
        XCTAssertEqual(ring.value as? String, "0 seconds remaining")
        XCTAssertEqual(primary.label, "Start again")
        XCTAssertFalse(skip.isEnabled)
        attach(name: "timer-done")

        reset.tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Start'"))
        XCTAssertEqual(step.label, "Step 1 of 5")
        element(app, Identifiers.Timer.plan).buttons["Focus"].tap()
        XCTAssertTrue(waitUntil(ring, "label == 'Focus'"))
        XCTAssertEqual(ring.value as? String, "25 minutes remaining")
        XCTAssertEqual(step.label, "Step 1 of 7")
        attach(name: "timer-focus")
    }

    /// The SessionActivity module's main path: starting a session starts one Live Activity, pausing keeps it,
    /// resetting ends it. A test can't read another process's Dynamic Island, so the app reports its activity
    /// count under `-sessionActivity.readout`, and the screenshot taken from the Home Screen shows the island.
    @MainActor
    func testTimerLiveActivity() throws {
        let app = XCUIApplication()
        app.launch(UITestLaunch(tab: Identifiers.Tabs.timer,
                                extra: ["-timer.intervals", "20,10,3", "-sessionActivity.readout", "YES"]))
        let primary = element(app, Identifiers.Timer.primary)
        try requireModuleUI("SessionTimer", appeared: primary.waitForExistence(timeout: 10), "no Start button on the Timer tab")
        let count = element(app, Identifiers.Timer.activityCount)
        try requireModuleUI("SessionActivity", appeared: count.waitForExistence(timeout: 5), "no Live Activity readout")
        XCTAssertEqual(count.label, "0")

        primary.tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Pause'"))
        if !waitUntil(count, "label == '1'", timeout: 10) {
            // The person (or this simulator) has Live Activities off for the app; the controller then does nothing.
            throw XCTSkip("Live Activities are not available in this environment; the phone check covers them")
        }
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2) // Let the island settle before the screenshot.
        attach(name: "live-activity-island")
        app.activate()
        XCTAssertTrue(primary.waitForExistence(timeout: 10))

        primary.tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Resume'"))
        XCTAssertEqual(count.label, "1", "Pausing keeps the activity")
        element(app, Identifiers.Timer.reset).tap()
        XCTAssertTrue(waitUntil(primary, "label == 'Start'"))
        XCTAssertTrue(waitUntil(count, "label == '0'", timeout: 10), "Resetting ends the activity")
    }
}
