import SwiftUI
#if canImport(TabShell)
import TabShell

/// Each scene owns its selection; each destination owns its navigation stack.
struct StarterTabsView: View {
    @State private var selection = TabSelection(tabs: StarterTab.items.map(\.id), defaultTab: .welcome)
    @State private var hasVisitedSettings = false

    var body: some View {
        TabShell(tabs: StarterTab.items, selection: selection) { tab in
            switch tab {
            case .welcome:
                NavigationStack {
                    ContentView(hasVisitedSettingsTab: hasVisitedSettings)
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
#if canImport(Settings)
        .onChange(of: selection.selectedTab, initial: true) { _, tab in
            if tab == .settings { hasVisitedSettings = true }
        }
#endif
    }
}
#endif
