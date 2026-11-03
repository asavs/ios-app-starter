import Foundation
import Observation

/// Scene-owned selection with last-used-tab restoration. Own one instance in the scene root's `@State`.
///
/// Only the stable raw value is stored. Navigation paths, badges, and app data belong to the host.
/// Separate instances navigate independently; a newly opened scene restores the last saved tab.
///
/// The list of tabs can change while the instance lives (`setTabs(_:defaultTab:)`), so a host whose
/// person chooses their tabs keeps one selection and one shell across that choice.
@MainActor @Observable
public final class TabSelection<ID: Hashable & RawRepresentable> where ID.RawValue == String {
    /// The destinations available right now, in display order. Change them with `setTabs`.
    public private(set) var tabs: [ID]

    private var currentTab: ID
    private let defaults: UserDefaults
    private let storageKey: String

    /// Bind the native tab view directly to this property. Unsupported destinations are ignored.
    public var selectedTab: ID {
        get { currentTab }
        set {
            guard tabs.contains(newValue) else { return }
            currentTab = newValue
            defaults.set(newValue.rawValue, forKey: storageKey)
        }
    }

    /// Restore a known tab, or use `defaultTab` if storage is empty, malformed, or names a removed tab.
    /// Give independent shells distinct keys; pass an isolated defaults suite in tests and previews.
    public init(tabs: [ID], defaultTab: ID, storageKey: String = "tabs.selected",
                defaults: UserDefaults = .standard) {
        Self.validate(tabs, defaultTab: defaultTab)
        precondition(!storageKey.isEmpty, "A tab selection needs a nonempty storage key")
        self.tabs = tabs
        self.defaults = defaults
        self.storageKey = storageKey
        let restored = defaults.string(forKey: storageKey).flatMap(ID.init(rawValue:))
        currentTab = restored.flatMap { tabs.contains($0) ? $0 : nil } ?? defaultTab
    }

    /// Replace the available destinations: the person chose or reordered their tabs, or a feature
    /// came or went. The selection stays where it is when that tab is still listed; otherwise it
    /// moves to `defaultTab` and that move is stored, so a relaunch lands on a tab that exists.
    public func setTabs(_ tabs: [ID], defaultTab: ID) {
        Self.validate(tabs, defaultTab: defaultTab)
        self.tabs = tabs
        if !tabs.contains(currentTab) { selectedTab = defaultTab }
    }

    /// Select a destination from a host-validated deep link. Unknown or unavailable IDs leave it alone.
    ///
    /// The host validates the URL's scheme, host, authorization, and any nested route before calling.
    @discardableResult
    public func select(rawValue: String) -> Bool {
        guard let tab = ID(rawValue: rawValue), tabs.contains(tab) else { return false }
        selectedTab = tab
        return true
    }

    private static func validate(_ tabs: [ID], defaultTab: ID) {
        precondition(!tabs.isEmpty, "A tab shell needs at least one destination")
        precondition(Set(tabs).count == tabs.count, "Tab IDs must be unique")
        precondition(tabs.contains(defaultTab), "The default tab must be available")
    }
}
