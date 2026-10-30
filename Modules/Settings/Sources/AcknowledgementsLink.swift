import SwiftUI

/// A row that opens `AcknowledgementsView`, for `SettingsView`'s `about:` rows. Hidden while the
/// list is empty. Accessibility identifier: `settings.acknowledgements`.
public struct AcknowledgementsLink: View {
    private let entries: [Acknowledgement]

    public init(_ entries: [Acknowledgement]) {
        self.entries = entries
    }

    public var body: some View {
        if entries.isEmpty == false {
            NavigationLink {
                AcknowledgementsView(entries)
            } label: {
                Label { Text("Acknowledgements", bundle: .module) } icon: { Image(systemName: "heart.text.square") }
            }
            .accessibilityIdentifier("settings.acknowledgements")
        }
    }
}
