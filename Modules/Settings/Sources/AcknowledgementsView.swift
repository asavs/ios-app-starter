import SwiftUI
import Theme

/// The Acknowledgements screen: one row per `Acknowledgement`, opening its link when it has one.
/// `SettingsView` pushes it from an `AcknowledgementsLink`. Accessibility identifier on each row:
/// `settings.acknowledgements.<id>`.
public struct AcknowledgementsView: View {
    private let entries: [Acknowledgement]
    @Environment(\.appTheme) private var theme

    public init(_ entries: [Acknowledgement]) {
        self.entries = entries
    }

    public var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(systemImage: "heart.text.square",
                               title: LocalizedStringResource("Nothing to acknowledge yet", bundle: .module),
                               message: LocalizedStringResource("Credits for third-party code and art appear here.", bundle: .module))
            } else {
                List(entries) { entry in
                    AcknowledgementRow(entry: entry)
                        .accessibilityIdentifier("settings.acknowledgements.\(entry.id)")
                }
            }
        }
        .navigationTitle(Text("Acknowledgements", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView([
            Acknowledgement(name: "iOS App Starter", author: "The starter's contributors", license: "MIT License",
                            url: URL(string: "https://github.com/asavs/ios-app-starter")),
            Acknowledgement(name: "A typeface", author: "A foundry", license: "SIL Open Font License"),
        ])
    }
}
