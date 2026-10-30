import SwiftUI
import Theme

/// The settings screen: an appearance picker, the app's own sections, and an About section.
///
/// ```swift
/// NavigationStack {
///     SettingsView {
///         Section("Account") { SecureSettingRow("API key", key: "api.key") }
///     } about: {
///         PrivacyNoticeLink(.myApp)
///         AcknowledgementsLink(MyApp.acknowledgements)
///     }
/// }
/// ```
///
/// Push it from a navigation link or present it in a sheet; it sets its own navigation title. The
/// appearance picker writes `AppSettings.appearanceKey` once its selection settles, so a root with
/// `.storedAppearance()` changes scheme right after the user taps. The About section shows the
/// version, then the `about` rows, under a footer saying that text size, contrast and Reduce Motion
/// follow the system (the HIG asks apps not to duplicate those settings). `PrivacyNoticeLink` and
/// `AcknowledgementsLink` push their screens onto the stack the app shows this view in.
///
/// Accessibility identifiers for UI tests: `settings.appearance`, `settings.version`.
public struct SettingsView<Extra: View, About: View>: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.appearanceKey) private var appearance: AppearancePreference = .system
    /// The picker's selection. It reaches `appearance` after the segmented control's selection has slid
    /// into place: switching the window's scheme mid-slide made the iOS 26 glass selection redraw its
    /// labels as stacked, displaced copies.
    @State private var choice: AppearancePreference
    private let extra: Extra
    private let about: About
    private let version: String?

    /// - Parameters:
    ///   - version: What the About section shows; the main bundle's version by default.
    ///   - extra: The app's own sections, placed between Appearance and About.
    ///   - about: Rows under the version in the About section: `PrivacyNoticeLink`,
    ///     `AcknowledgementsLink`, or the app's own `LabeledContent`.
    public init(version: String? = AppInfo.version(), @ViewBuilder extra: () -> Extra, @ViewBuilder about: () -> About) {
        self.version = version
        self.extra = extra()
        self.about = about()
        _choice = State(initialValue: AppSettings().appearance)
    }

    /// Long enough for the segmented control's selection to slide clear: on an iOS 26.3 iPhone the
    /// glitch appeared at 175 ms and not at 200 ms.
    static var appearanceDelay: Duration { .milliseconds(200) }

    private var showsAbout: Bool { version != nil || About.self != EmptyView.self }

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
            if showsAbout {
                Section {
                    if let version {
                        LabeledContent {
                            Text(verbatim: version)
                                .textSelection(.enabled) // Copyable into a bug report.
                        } label: {
                            Text("Version", bundle: .module)
                        }
                        .font(theme.typography.body)
                        .accessibilityIdentifier("settings.version")
                    }
                    about
                } header: {
                    Text("About", bundle: .module)
                } footer: {
                    Text("Text size, contrast and Reduce Motion follow your device settings.", bundle: .module)
                }
            }
        }
        .navigationTitle(Text("Settings", bundle: .module))
    }
}

public extension SettingsView where About == EmptyView {
    init(version: String? = AppInfo.version(), @ViewBuilder extra: () -> Extra) {
        self.init(version: version, extra: extra) { EmptyView() }
    }
}

public extension SettingsView where Extra == EmptyView, About == EmptyView {
    init(version: String? = AppInfo.version()) {
        self.init(version: version) { EmptyView() } about: { EmptyView() }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView(version: "1.0 (1)") {
            Section("Account") {
                SecureSettingRow("API key", key: "preview.api.key", store: InMemorySecureStore())
            }
            Section {
                ResetLocalDataButton(reset: LocalDataReset([]))
            }
        } about: {
            PrivacyNoticeLink(PrivacyNotice(summary: "Works offline.", deletion: "Erase Local Data removes it."))
            AcknowledgementsLink([Acknowledgement(name: "A package", author: "Someone", license: "MIT License")])
        }
    }
}
