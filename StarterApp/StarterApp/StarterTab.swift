import Foundation
#if canImport(TabShell)
import TabShell

/// The app builder edits this enum, its labels, and the matching screens in StarterTabsView.
enum StarterTab: String {
    case welcome
#if canImport(SessionTimer) && canImport(TimerRing)
    case timer
#endif
#if canImport(Settings)
    case settings
#endif

    static var items: [TabItem<StarterTab>] {
        var tabs = [TabItem(id: StarterTab.welcome, title: "Welcome", systemImage: "house")]
#if canImport(SessionTimer) && canImport(TimerRing)
        tabs.append(TabItem(id: .timer, title: "Timer", systemImage: "timer"))
#endif
#if canImport(Settings)
        tabs.append(TabItem(id: .settings, title: "Settings", systemImage: "gearshape"))
#endif
        return tabs
    }
}
#endif
