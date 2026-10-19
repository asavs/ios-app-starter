import SwiftUI

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.standard
}

public extension EnvironmentValues {
    /// The active theme; `AppTheme.standard` unless an ancestor set one with `appTheme(_:)`.
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

public extension View {
    /// Supplies the theme to this view and everything below it. Apply once at the app root.
    func appTheme(_ theme: AppTheme) -> some View {
        environment(\.appTheme, theme)
    }
}
