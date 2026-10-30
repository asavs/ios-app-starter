import SwiftUI

/// A row that opens `PrivacyNoticeView`, for `SettingsView`'s `about:` rows. Accessibility
/// identifier: `settings.privacy`.
public struct PrivacyNoticeLink: View {
    private let notice: PrivacyNotice

    public init(_ notice: PrivacyNotice) {
        self.notice = notice
    }

    public var body: some View {
        // A destination link, like the template's other pushes: Settings views are shown in stacks
        // the app owns, so the module registers no destination types on them.
        NavigationLink {
            PrivacyNoticeView(notice)
        } label: {
            Label { Text("Privacy and Data", bundle: .module) } icon: { Image(systemName: "hand.raised") }
        }
        .accessibilityIdentifier("settings.privacy")
    }
}
