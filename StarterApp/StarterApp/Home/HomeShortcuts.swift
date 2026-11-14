import SwiftUI
#if canImport(TabShell)
import Theme

/// A row for each other chosen tab, in the person's order, that switches to it: the same title,
/// symbol and one-line summary the tab chooser shows.
struct HomeShortcuts: View {
    let features: [StarterFeature]
    @Environment(\.openTab) private var openTab

    var body: some View {
        HomeSection(tab: .welcome, title: "Shortcuts") {
            ForEach(features) { feature in
                if feature != features.first {
                    Divider()
                }
                Button { openTab(feature.id) } label: {
                    HomeRow(systemImage: feature.systemImage, title: Text(feature.title), detail: Text(feature.summary))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(Identifiers.Home.shortcut(feature.id.rawValue))
            }
        }
    }
}
#endif
