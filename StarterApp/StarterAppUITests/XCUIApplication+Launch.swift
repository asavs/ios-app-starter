import XCTest

extension XCUIApplication {
    /// Launches the app into a scenario (`UITestLaunch`): its own defaults suite, an in-memory or
    /// named database, pinned tab, onboarding and tips. Pass `scenario.relaunch` for a second
    /// launch that must find the first one's data.
    func launch(_ scenario: UITestLaunch) {
        launchArguments = scenario.arguments
        launch()
    }

    /// Opens a URL as if from another app, launching into the scenario when the app isn't running.
    func open(_ url: URL, in scenario: UITestLaunch) {
        launchArguments = scenario.arguments
        open(url)
    }
}

extension UITestLaunch {
    /// Past onboarding, on a tab, with tips hidden: where most tests start.
    static func tab(_ tab: String) -> UITestLaunch {
        UITestLaunch(tab: tab)
    }

    /// A first launch: the welcome tab under the onboarding flow.
    static let onboarding = UITestLaunch(tab: Identifiers.Tabs.welcome, onboarding: .shows)

    /// `extra` arguments for the largest accessibility text size.
    static let largestTextSize = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
}
