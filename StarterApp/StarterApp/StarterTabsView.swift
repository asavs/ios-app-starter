import SwiftUI
#if canImport(TabShell)
import TabShell

/// Each scene owns its selection; each destination owns its navigation stack.
struct StarterTabsView: View {
    @State private var selection = TabSelection(tabs: StarterTab.items.map(\.id), defaultTab: .welcome)
    /// Whether this launch reset the tips: then a Settings tab restored from before the reset is not a visit.
    var tipsWereReset = false
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
        // A launch that restores Settings counts as a visit, except right after a tips reset: the reset
        // buttons are on the Settings tab, so that launch would otherwise retire the tip unseen.
        .onAppear {
            if selection.selectedTab == .settings && !tipsWereReset { hasVisitedSettings = true }
        }
        .onChange(of: selection.selectedTab) { _, tab in
            if tab == .settings { hasVisitedSettings = true }
        }
#endif
    }
}
#endif
