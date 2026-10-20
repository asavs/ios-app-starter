import Foundation
import SwiftUI
import Theme

/// The app's non-secret preferences, stored in `UserDefaults` under stable keys.
///
/// Today that is the appearance choice (`AppearancePreference` from the Theme module). Read or
/// write it from any code with this value; views bind to the same key with `@AppStorage`, so the
/// `SettingsView` picker and `.storedAppearance()` at the root stay in sync. Secrets never go here;
/// they belong in a `SecureStore`.
///
/// A launch argument overrides the stored value for UI tests: `-settings.appearance dark`.
// `UserDefaults` is documented as thread-safe but not annotated Sendable; the value holds nothing else.
public struct AppSettings: @unchecked Sendable {
    /// The `UserDefaults` key for the appearance choice: `settings.appearance`.
    public static let appearanceKey = "settings.appearance"
    /// Every key this module stores, for a "reset settings" action.
    public static let keys = [appearanceKey]

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The light/dark choice; `.system` until the user picks one.
    public var appearance: AppearancePreference {
        get {
            defaults.string(forKey: Self.appearanceKey).flatMap(AppearancePreference.init(rawValue:)) ?? .system
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.appearanceKey)
        }
    }

    /// Forgets every stored preference.
    public func reset() {
        for key in Self.keys {
            defaults.removeObject(forKey: key)
        }
    }
}

public extension View {
    /// Applies the stored appearance choice as the preferred color scheme. Apply once at the root.
    func storedAppearance(store: UserDefaults = .standard) -> some View {
        modifier(StoredAppearance(store: store))
    }
}

struct StoredAppearance: ViewModifier {
    @AppStorage private var appearance: AppearancePreference

    init(store: UserDefaults) {
        _appearance = AppStorage(wrappedValue: .system, AppSettings.appearanceKey, store: store)
    }

    func body(content: Content) -> some View {
        content.preferredColorScheme(appearance.colorScheme)
    }
}
