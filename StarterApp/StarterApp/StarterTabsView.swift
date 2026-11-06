import SwiftUI
#if canImport(TabShell)
import TabShell

/// Each scene owns its choice of tabs and its selection; each destination owns its navigation stack.
///
/// The shell gets every available feature's descriptor once; which tabs show, and in what order,
/// follows `FeatureChoices` through the selection's tab list.
struct StarterTabsView: View {
    @State private var choices: FeatureChoices
    @State private var selection: TabSelection<StarterTab>
    /// A deep link named a feature this build doesn't include: the alert that says so.
    @State private var unavailable: StarterFeature?

    init() {
        let choices = FeatureChoices()
        _choices = State(initialValue: choices)
        _selection = State(initialValue: TabSelection(tabs: choices.chosen, defaultTab: choices.defaultTab,
                                                      defaults: StarterDefaults.store))
    }

    var body: some View {
        TabShell(tabs: StarterFeature.available.map(\.item), selection: selection) { tab in
            destination(tab)
        }
        .onChange(of: choices.chosen) { _, chosen in
            selection.setTabs(chosen, defaultTab: choices.defaultTab)
        }
        // starterapp://settings selects that tab; see DeepLink for what is accepted and FeatureChoices
        // for what a link to a hidden or missing feature does.
        .onOpenURL(perform: open)
        .alert(Text("\(String(localized: unavailable?.title ?? "This feature")) isn't in this build"),
               isPresented: Binding { unavailable != nil } set: { if !$0 { unavailable = nil } },
               presenting: unavailable) { _ in
            Button("OK") { unavailable = nil }
        } message: { feature in
            Text("\(String(localized: feature.title)) was left out when this app was built. The link opened nothing.")
        }
    }

    @ViewBuilder
    private func destination(_ tab: StarterTab) -> some View {
        switch tab {
        case .welcome:
            NavigationStack {
                ContentView()
                    .navigationTitle(Text(StarterFeature.feature(.welcome).title))
            }
        case .library:
#if canImport(Database) && canImport(Attachments)
            NavigationStack {
                LibraryView()
            }
#else
            FeatureUnavailableView(feature: StarterFeature.feature(.library))
#endif
        case .notes:
#if canImport(Database)
            NavigationStack {
                NotesView()
            }
#else
            FeatureUnavailableView(feature: StarterFeature.feature(.notes))
#endif
        case .timer:
#if canImport(SessionTimer) && canImport(TimerRing)
            NavigationStack {
                StarterTimerView()
            }
#else
            FeatureUnavailableView(feature: StarterFeature.feature(.timer))
#endif
        case .settings:
#if canImport(Settings)
            NavigationStack {
                StarterSettingsView()
            }
#else
            FeatureUnavailableView(feature: StarterFeature.feature(.settings))
#endif
        }
    }

    private func open(_ url: URL) {
        guard let raw = DeepLink.tab(in: url) else { return }
        switch choices.open(link: raw) {
        case .select(let tab):
            selection.select(rawValue: tab.rawValue)
        case .revealed(let tab):
            // The choice changed this instant; give the selection the new list before selecting,
            // rather than waiting for the view update to do it.
            selection.setTabs(choices.chosen, defaultTab: choices.defaultTab)
            selection.select(rawValue: tab.rawValue)
        case .unavailable(let tab):
            unavailable = StarterFeature.feature(tab)
        case .ignore:
            break
        }
    }
}

/// The destination for a feature this build left out. The shell never lists one, since the
/// choice is normalized to available features, so this is the fallback a stray path shows instead
/// of an empty screen.
private struct FeatureUnavailableView: View {
    let feature: StarterFeature

    var body: some View {
        ContentUnavailableView {
            Label { Text(feature.title) } icon: { Image(systemName: feature.systemImage) }
        } description: {
            Text("\(String(localized: feature.title)) was left out when this app was built.")
        }
    }
}
#endif
