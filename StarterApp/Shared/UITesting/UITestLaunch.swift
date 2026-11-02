import Foundation

/// What a UI test asks of the app at launch. The test builds one and launches with `arguments`;
/// the app reads `current` back from its own. Compiled into the app and the UI test bundle from
/// StarterApp/Shared, so the argument names live in one place (docs/ci.md, "UI test scenarios").
///
/// The argument domain (`-key value`) shadows stored defaults for reads, which is how the tab, the
/// onboarding record and the tips are pinned; it never resets anything. So a test launch also puts
/// the app's defaults in a suite of their own (`StarterDefaults`), its database in memory or in a
/// named store under `directory`, and its attachments under `directory`, and a `resets` launch
/// empties all three first. Debug builds only: a release build reads nothing here.
struct UITestLaunch: Equatable {
    enum Onboarding: Equatable {
        /// The flow shows, as on a first launch.
        case shows
        /// Recorded as completed, past any version of the flow.
        case completed
        /// Nothing pinned: the stored record decides, for a relaunch that checks it was kept.
        case asStored
    }

    enum Tips: Equatable {
        /// Off every screen the test inspects.
        case hidden
        /// The real rules with the history forgotten, so the first tip shows.
        case fresh
    }

    /// The tab to open (a `StarterTab` raw value, see `Identifiers.Tabs`); nil restores the stored selection.
    var tab: String?
    var onboarding: Onboarding = .completed
    var tips: Tips = .hidden
    /// A named store under `directory`, for a test that relaunches into the same records; nil keeps
    /// the database in memory, gone with the process.
    var store: String?
    /// Empty the suite, the store and the attachments before this launch: a test's first launch.
    /// `relaunch` keeps them.
    var resets = true
    /// A module's own arguments, appended as given, such as `-attachments.fakeCamera`.
    var extra: [String] = []

    init(tab: String? = nil, onboarding: Onboarding = .completed, tips: Tips = .hidden,
         store: String? = nil, resets: Bool = true, extra: [String] = []) {
        self.tab = tab
        self.onboarding = onboarding
        self.tips = tips
        self.store = store
        self.resets = resets
        self.extra = extra
    }

    /// The same scenario without emptying anything: the second launch of a test.
    var relaunch: UITestLaunch {
        var launch = self
        launch.resets = false
        return launch
    }

    /// The launch arguments for `XCUIApplication`. Every flag carries a value, because the
    /// argument domain reads pairs and a bare flag would swallow the next argument.
    var arguments: [String] {
        var arguments = [Self.flag, "YES"]
        if resets { arguments += [Self.resetFlag, "YES"] }
        if let tab { arguments += ["-tabs.selected", tab] }
        switch onboarding {
        case .shows: arguments += ["-onboarding.completedVersion", "0"]
        case .completed: arguments += ["-onboarding.completedVersion", "99"]
        case .asStored: break
        }
        arguments += ["-onboarding.permissions", "granted"] // The primer's fake requester: no system alert.
        switch tips {
        case .hidden: arguments += ["-tips.testing", "hideAll"]
        case .fresh: arguments += ["-tips.reset", "YES"]
        }
        if let store {
            arguments += ["-database.store", store]
            if resets { arguments += ["-database.reset", "YES"] }
        }
        return arguments + extra
    }

    static let flag = "-ui-testing"
    static let resetFlag = "-ui-testing.reset"
    /// The `UserDefaults` suite a test launch uses instead of `.standard`.
    static let suiteName = "ui-testing"
    /// Where a test launch keeps its files: the named store and the attachments.
    static var directory: URL {
        URL.temporaryDirectory.appending(path: "ui-testing", directoryHint: .isDirectory)
    }

    /// The app's reading of its own arguments: nil on a normal launch and in a release build. Only
    /// what the app itself acts on comes back (`resets`, `store`); the tab, onboarding and tips
    /// reach their modules through the argument domain.
    static let current: UITestLaunch? = {
#if DEBUG
        UITestLaunch(arguments: CommandLine.arguments)
#else
        nil
#endif
    }()

    init?(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        guard value(after: Self.flag) == "YES" else { return nil }
        self.init(tab: value(after: "-tabs.selected"), store: value(after: "-database.store"),
                  resets: value(after: Self.resetFlag) == "YES")
    }
}
