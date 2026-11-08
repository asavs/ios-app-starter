import XCTest

/// Shared setup and helpers for the UI tests. The tests are split into classes by area (onboarding,
/// settings, timer, and the shell with theme and deep links) because XCTest hands whole classes to
/// parallel simulator clones: a single class would keep every test on one clone.
class StarterUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false // Later steps depend on earlier ones.
    }

    /// Swipes up, a few times at most, until the element is on screen.
    /// Compares frames instead of asking `isHittable`: for an element below the fold, XCTest can fail
    /// the test with "Failed to determine hittability" rather than answer false.
    @MainActor
    func scroll(_ app: XCUIApplication, to element: XCUIElement, swipes: Int = 6) -> Bool {
        let window = app.windows.firstMatch
        for _ in 0..<swipes where !(element.exists && window.frame.contains(element.frame)) {
            app.swipeUp()
        }
        return waitUntilHittable(element)
    }

    /// Waits until the element's frame overlaps the window and its page has slid in. At the largest text
    /// sizes a page's combined card runs past the bottom edge, so its centre, which `isHittable` tests,
    /// can sit under the Continue button while the page is plainly on screen.
    @MainActor
    func waitUntilOnScreen(_ app: XCUIApplication, _ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        let window = app.windows.firstMatch
        let shown = NSPredicate { _, _ in
            guard element.exists else { return false }
            let frame = element.frame, bounds = window.frame
            return frame.intersects(bounds) && frame.minX >= bounds.minX - 1 && frame.minX < bounds.midX
        }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: shown, object: nil)], timeout: timeout) == .completed
    }

    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        waitUntil(element, "exists == false", timeout: timeout)
    }

    /// Waits for the element to match a predicate format, such as `isSelected == true`.
    func waitUntil(_ element: XCUIElement, _ format: String, timeout: TimeInterval = 15) -> Bool {
        let matched = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        return XCTWaiter().wait(for: [matched], timeout: timeout) == .completed
    }

    /// Waits for the element to become hittable (or not), which outlasts the flow's short transitions.
    /// The limit is generous because on a loaded hosted runner one hierarchy snapshot of the paged flow
    /// has taken over 4 s, so a 5 s wait expired after a single check; a settled element returns at once.
    /// An element on a page the pager has not laid out yet reports an infinite frame, and asking it for
    /// `isHittable` then fails the test ("Activation point invalid") instead of answering; on the hosted
    /// runner that happened to the primer's footnote. Such an element counts as not hittable yet.
    func waitUntilHittable(_ element: XCUIElement, expected: Bool = true, timeout: TimeInterval = 15) -> Bool {
        waitUntil(timeout: timeout) { self.isHittable(element) == expected }
    }

    /// Whether the element is on screen and can take a tap now, without waiting. An element that is
    /// missing or still has an infinite frame counts as not hittable (see `waitUntilHittable`).
    func isHittable(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard frame.minX.isFinite, frame.minY.isFinite, !frame.isEmpty else { return false }
        return element.isHittable
    }

    /// Waits for a condition the predicate-format helpers can't express, such as two frames' order.
    func waitUntil(timeout: TimeInterval = 15, _ condition: @escaping () -> Bool) -> Bool {
        let met = NSPredicate { _, _ in condition() }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: met, object: nil)], timeout: timeout) == .completed
    }

    /// Performs an action and waits for its result, repeating the action once if nothing happened.
    /// On a loaded hosted runner a tap or a drag is sometimes synthesized and then lost: a switch kept
    /// its value for ten seconds after its tap, an onboarding step stayed after Continue, and a dragged
    /// tab kept its place (2026-11-07). `unchanged` must say the app is still where the action started,
    /// so a slow action that did land is never performed twice.
    @MainActor
    func perform(_ action: () -> Void, until arrived: @escaping () -> Bool,
                 retryingIf unchanged: () -> Bool, timeout: TimeInterval = 10) -> Bool {
        action()
        if waitUntil(timeout: timeout, arrived) { return true }
        guard unchanged() else { return waitUntil(timeout: timeout, arrived) }
        XCTContext.runActivity(named: "Nothing changed after the first attempt; repeating it") { _ in }
        action()
        return waitUntil(timeout: timeout, arrived)
    }

    /// Waits until the element's frame stops changing: a push, a sheet or a swipe has finished.
    func waitUntilSettled(_ element: XCUIElement, checks: Int = 20) -> Bool {
        for _ in 0..<checks {
            guard element.exists else { return false }
            let frame = element.frame
            Thread.sleep(forTimeInterval: 0.25)
            if element.exists, element.frame == frame, frame.minX.isFinite, !frame.isEmpty { return true }
        }
        return false
    }

    /// Flips a `Toggle` in a `Form` and waits for its value to change. The identifier lands on a
    /// switch spanning the row, whose center is the label, so the tap goes to the knob on the row's
    /// trailing edge by coordinate. The row is scrolled clear of the floating tab bar and left to
    /// settle first: a tap mid-animation lands elsewhere, and asking the inner switch whether it's
    /// hittable fails the test outright while the list settles ("Activation point invalid"), as it
    /// did on the hosted runner.
    @MainActor
    func flip(_ app: XCUIApplication, _ toggle: XCUIElement) {
        let before = toggle.value as? String ?? ""
        XCTAssertTrue(scroll(app, to: toggle), "\(toggle) should be on screen")
        if toggle.frame.maxY > app.windows.firstMatch.frame.maxY - 120 { app.swipeUp() }
        XCTAssertTrue(waitUntilSettled(toggle), "\(toggle) should stop moving")
        let value = { toggle.exists ? toggle.value as? String ?? "" : before }
        XCTAssertTrue(perform({ toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap() },
                              until: { value() != before }, retryingIf: { value() == before }),
                      "\(toggle) should flip")
    }

    /// Any element with this accessibility identifier; containers and combined rows vary in type.
    @MainActor
    func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func attach(name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Gives a text field keyboard focus. On the iOS 27 simulator a single tap on a `SecureField` in a
    /// `Form` row sometimes selects the row without focusing the field; tapping again focuses it.
    /// Focus is read from the keyboard, not the field: on the hosted runner the field's
    /// `hasKeyboardFocus` stayed false through four taps while the recording showed its cursor and
    /// keyboard, and one snapshot there takes over a second. Type with `app.typeText` afterwards.
    @MainActor
    func focus(_ field: XCUIElement, in app: XCUIApplication, attempts: Int = 3) throws {
        let keyboard = app.keyboards.firstMatch
        for attempt in 1...attempts {
            field.tap()
            let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: keyboard)
            if XCTWaiter().wait(for: [shown], timeout: 10) == .completed { return }
            XCTContext.runActivity(named: "No keyboard after tap \(attempt)") { _ in }
        }
        XCTFail("\(field.identifier) did not bring up the keyboard after \(attempts) taps")
        throw ModuleUIMissing(description: "no keyboard for \(field.identifier)")
    }

    /// Settings is a native tab when TabShell is enabled, otherwise the original toolbar button.
    @MainActor
    func settingsButton(in app: XCUIApplication) -> XCUIElement {
        let gear = NSPredicate(format: "identifier == %@", Identifiers.Welcome.settings)
        let tab = tabPredicate(Identifiers.Tabs.settings, title: "Settings")
        return app.buttons.matching(NSCompoundPredicate(orPredicateWithSubpredicates: [gear, tab])).firstMatch
    }

    /// A TabShell tab button: by its `tabs.<id>` identifier, or by its English title, because iOS 26.3
    /// leaves tab bar buttons without the identifier (with both `Tab` and `tabItem`; iOS 27 keeps it).
    @MainActor
    /// The tab's button: in the tab bar on a phone; on an iPad the tabs render as a top bar that
    /// isn't a tab bar to the accessibility tree, so the lookup falls back to any button that
    /// carries the tab's identifier (or its title where the identifier is missing).
    func tabButton(in app: XCUIApplication, _ id: String, title: String) -> XCUIElement {
        if hasTabBar == nil { hasTabBar = app.tabBars.firstMatch.waitForExistence(timeout: 10) }
        let predicate = tabPredicate(id, title: title)
        return hasTabBar == true ? app.tabBars.buttons.matching(predicate).firstMatch
            : app.buttons.matching(predicate).firstMatch
    }

    /// Whether this app draws a tab bar, asked once per test: on an iPhone the buttons are queried
    /// inside it (a narrow query a loaded runner answers in time), on an iPad among all buttons.
    private var hasTabBar: Bool?

    func tabPredicate(_ id: String, title: String) -> NSPredicate {
        NSPredicate(format: "identifier == %@ OR (identifier == '' AND label == %@)", Identifiers.Tabs.button(id), title)
    }

    /// Modules the lane built the app with, from `scripts/test-ios.sh` (`TEST_RUNNER_IOS_ENABLED_MODULES`);
    /// `nil` when unknown, such as a run from Xcode.
    static let enabledModules: Set<String>? = ProcessInfo.processInfo.environment["IOS_ENABLED_MODULES"]
        .map { Set($0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }).filter { !$0.isEmpty } }

    struct ModuleUIMissing: Error, CustomStringConvertible {
        let description: String
    }

    /// Skips the test when `module` is disabled in this build; fails it when the lane says the module is
    /// enabled but its UI did not appear, so a stale launch argument cannot hide behind a skip.
    func requireModuleUI(_ module: String, appeared: Bool, _ detail: String) throws {
        guard !appeared else { return }
        if let enabled = Self.enabledModules, enabled.contains(module) {
            let message = "\(module) is enabled in this build but \(detail)"
            XCTFail(message)
            throw ModuleUIMissing(description: message)
        }
        throw XCTSkip("\(module) module disabled: \(detail)")
    }
}
