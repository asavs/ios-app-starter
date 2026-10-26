import Foundation
import Observation

/// Scene-owned selection with last-used-tab restoration. Own one instance in the scene root's `@State`.
///
/// Only the stable raw value is stored. Navigation paths, badges, and app data belong to the host.
/// Separate instances navigate independently; a newly opened scene restores the last saved tab.
@MainActor @Observable
public final class TabSelection<ID: Hashable & RawRepresentable> where ID.RawValue == String {
    /// The destinations available for this instance's lifetime, in display order.
    public let tabs: [ID]

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
        precondition(!tabs.isEmpty, "A tab shell needs at least one destination")
        precondition(Set(tabs).count == tabs.count, "Tab IDs must be unique")
        precondition(tabs.contains(defaultTab), "The default tab must be available")
        precondition(!storageKey.isEmpty, "A tab selection needs a nonempty storage key")
        self.tabs = tabs
        self.defaults = defaults
        self.storageKey = storageKey
        let restored = defaults.string(forKey: storageKey).flatMap(ID.init(rawValue:))
        currentTab = restored.flatMap { tabs.contains($0) ? $0 : nil } ?? defaultTab
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
}
