import SwiftUI
import Theme

/// The settings screen: an appearance picker, the app's own sections, and the version.
///
/// ```swift
/// NavigationStack {
///     SettingsView {
///         Section("Account") { SecureSettingRow("API key", key: "api.key") }
///     }
/// }
/// ```
///
/// Push it from a navigation link or present it in a sheet; it sets its own navigation title. The
/// appearance picker binds to `AppSettings.appearanceKey`, so a root with `.storedAppearance()`
/// changes scheme as the user taps. Accessibility identifiers for UI tests: `settings.appearance`,
/// `settings.version`.
public struct SettingsView<Extra: View>: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.appearanceKey) private var appearance: AppearancePreference = .system
    private let extra: Extra
    private let version: String?

    /// - Parameters:
    ///   - version: What the About section shows; the main bundle's version by default.
    ///   - extra: The app's own sections, placed between Appearance and About.
    public init(version: String? = AppInfo.version(), @ViewBuilder extra: () -> Extra) {
        self.version = version
        self.extra = extra()
    }

    public var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.appearance")
            }
            extra
            if let version {
                Section("About") {
                    LabeledContent("Version", value: version)
                        .font(theme.typography.body)
                        .accessibilityIdentifier("settings.version")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

public extension SettingsView where Extra == EmptyView {
    init(version: String? = AppInfo.version()) {
        self.init(version: version) { EmptyView() }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView(version: "1.0 (1)") {
            Section("Account") {
                SecureSettingRow("API key", key: "preview.api.key", store: InMemorySecureStore())
            }
        }
    }
}
