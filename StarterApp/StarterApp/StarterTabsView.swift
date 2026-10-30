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
#if canImport(SessionTimer) && canImport(TimerRing)
            case .timer:
                NavigationStack {
                    StarterTimerView()
                }
#endif
#if canImport(Settings)
            case .settings:
                NavigationStack {
                    StarterSettingsView()
                }
#endif
            }
        }
        // starterapp://settings selects that tab; see DeepLink for what is accepted.
        .onOpenURL { url in
            if let tab = DeepLink.tab(in: url) { selection.select(rawValue: tab) }
        }
    }
}
#endif
