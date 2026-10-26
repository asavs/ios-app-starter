import Foundation
#if canImport(TabShell)
import TabShell

/// The app builder edits this enum, its labels, and the matching screens in StarterTabsView.
enum StarterTab: String {
    case welcome
#if canImport(Settings)
    case settings
#endif

    static var items: [TabItem<StarterTab>] {
        var tabs = [TabItem(id: StarterTab.welcome, title: "Welcome", systemImage: "house")]
#if canImport(Settings)
        tabs.append(TabItem(id: .settings, title: "Settings", systemImage: "gearshape"))
#endif
        return tabs
    }
}
#endif
