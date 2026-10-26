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
/// appearance picker writes `AppSettings.appearanceKey` once its selection settles, so a root with
/// `.storedAppearance()` changes scheme right after the user taps. Accessibility identifiers for UI tests: `settings.appearance`,
/// `settings.version`.
public struct SettingsView<Extra: View>: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.appearanceKey) private var appearance: AppearancePreference = .system
    /// The picker's selection. It reaches `appearance` after the segmented control's selection has slid
    /// into place: switching the window's scheme mid-slide made the iOS 26 glass selection redraw its
    /// labels as stacked, displaced copies.
    @State private var choice: AppearancePreference
    private let extra: Extra
    private let version: String?

    /// - Parameters:
    ///   - version: What the About section shows; the main bundle's version by default.
    ///   - extra: The app's own sections, placed between Appearance and About.
    public init(version: String? = AppInfo.version(), @ViewBuilder extra: () -> Extra) {
        self.version = version
        self.extra = extra()
        _choice = State(initialValue: AppSettings().appearance)
    }

    /// Long enough for the segmented control's selection to finish sliding.
    static var appearanceDelay: Duration { .milliseconds(400) }

    public var body: some View {
        Form {
            Section {
                Picker(selection: $choice) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                } label: {
                    Text("Appearance", bundle: .module)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.appearance")
                // A new tap restarts the wait, so only the last choice is applied.
                .task(id: choice) {
                    guard choice != appearance,
                          (try? await Task.sleep(for: Self.appearanceDelay)) != nil else { return }
                    appearance = choice
                }
                .onChange(of: appearance) { _, stored in choice = stored } // Changed elsewhere, such as a reset.
            } header: {
                Text("Appearance", bundle: .module)
            }
            extra
            if let version {
                Section {
                    LabeledContent {
                        Text(verbatim: version)
                    } label: {
                        Text("Version", bundle: .module)
                    }
                    .font(theme.typography.body)
                    .accessibilityIdentifier("settings.version")
                } header: {
                    Text("About", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("Settings", bundle: .module))
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
