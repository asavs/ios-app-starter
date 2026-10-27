import SwiftUI
#if canImport(TabShell)
import TabShell

/// Each scene owns its selection; each destination owns its navigation stack.
struct StarterTabsView: View {
    @State private var selection = TabSelection(tabs: StarterTab.items.map(\.id), defaultTab: .welcome)

    var body: some View {
        TabShell(tabs: StarterTab.items, selection: selection) { tab in
            switch tab {
            case .welcome:
                NavigationStack {
                    ContentView()
                        .navigationTitle("Welcome")
                }
#if canImport(Settings)
            case .settings:
                NavigationStack {
                    StarterSettingsView()
                }
#endif
            }
        }
    }
}
#endif
