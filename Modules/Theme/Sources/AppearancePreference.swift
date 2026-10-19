import SwiftUI

/// The user's light/dark choice, as an app's settings would store it.
///
/// Apply it at the root with `.preferredColorScheme(preference.colorScheme)`. The raw values are
/// stable storage keys (`"system"`, `"light"`, `"dark"`), so `@AppStorage` and `Codable` settings
/// can persist the enum directly.
public enum AppearancePreference: String, CaseIterable, Codable, Sendable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    /// `nil` follows the device setting, which is what `preferredColorScheme` expects for "system".
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Short label for a picker row.
    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
