import SwiftUI
import Theme

/// The Privacy and Data screen: a `PrivacyNotice` as a form. `SettingsView` pushes it from a
/// `PrivacyNoticeLink`. Accessibility identifiers: `settings.privacy.summary`, `settings.privacy.policy`.
public struct PrivacyNoticeView: View {
    private let notice: PrivacyNotice
    @Environment(\.appTheme) private var theme

    public init(_ notice: PrivacyNotice) {
        self.notice = notice
    }

    public var body: some View {
        Form {
            Section {
                Text(notice.summary)
                    .accessibilityIdentifier("settings.privacy.summary")
            }
            if notice.stored.isEmpty == false {
                Section {
                    ForEach(Array(notice.stored.enumerated()), id: \.offset) { _, item in
                        Text(item)
                    }
                } header: {
                    Text("Stored on this device", bundle: .module)
                }
            }
            Section {
                if notice.shared.isEmpty {
                    Text("Nothing. The app sends no data anywhere.", bundle: .module)
                        .foregroundStyle(theme.colors.textSecondary)
                } else {
                    ForEach(Array(notice.shared.enumerated()), id: \.offset) { _, item in
                        Text(item)
                    }
                }
            } header: {
                Text("Leaves this device", bundle: .module)
            }
            Section {
                Text(notice.deletion)
            } header: {
                Text("Deleting your data", bundle: .module)
            }
            if let url = notice.policyURL {
                Section {
                    Link(destination: url) {
                        Label { Text("Privacy Policy", bundle: .module) } icon: { Image(systemName: "doc.text") }
                    }
                    .accessibilityIdentifier("settings.privacy.policy")
                }
            }
        }
        .navigationTitle(Text("Privacy and Data", bundle: .module))
        .inlineNavigationTitle()
    }
}

#Preview {
    NavigationStack {
        PrivacyNoticeView(PrivacyNotice(summary: "Works offline. Everything stays on this device.",
                                        stored: ["Your settings", "Saved secrets, in the Keychain"],
                                        deletion: "Erase Local Data in Settings removes all of it.",
                                        policyURL: URL(string: "https://example.com/privacy")))
    }
}
