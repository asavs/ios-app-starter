import SwiftUI
import Theme

/// Native top-level navigation; the host supplies every label, symbol, badge, and destination view.
///
/// Put a separate `NavigationStack` inside each destination that needs hierarchical navigation.
/// Do not wrap the shell in a shared stack: each tab should keep its own navigation context.
public struct TabShell<ID: Hashable & RawRepresentable, Content: View>: View where ID.RawValue == String {
    @Environment(\.appTheme) private var theme
    @Bindable private var selection: TabSelection<ID>
    private let tabs: [TabItem<ID>]
    private let content: (ID) -> Content

    public init(tabs: [TabItem<ID>], selection: TabSelection<ID>,
                @ViewBuilder content: @escaping (ID) -> Content) {
        precondition(tabs.map(\.id) == selection.tabs,
                     "The shell and its selection must describe the same tabs in the same order")
        self.tabs = tabs
        self.selection = selection
        self.content = content
    }

    public var body: some View {
        Group {
            if #available(iOS 18, macOS 15, *) {
                TabView(selection: $selection.selectedTab) {
                    ForEach(tabs) { tab in
                        Tab(value: tab.id) {
                            content(tab.id)
                        } label: {
                            Label { Text(tab.title) } icon: { Image(systemName: tab.systemImage) }
                        }
                        .badge(tab.badgeCount)
                        .accessibilityIdentifier(tab.accessibilityIdentifier)
                    }
                }
            } else {
                // The Tab API starts at iOS 18 / macOS 15. Keep the native iOS 17 presentation.
                TabView(selection: $selection.selectedTab) {
                    ForEach(tabs) { tab in
                        content(tab.id)
                            .tabItem {
                                Label { Text(tab.title) } icon: { Image(systemName: tab.systemImage) }
                                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                            }
                            .tag(tab.id)
                            .badge(tab.badgeCount)
                    }
                }
            }
        }
        .tint(theme.colors.accent)
        // Native bars own their material, safe areas, selected traits, and motion preferences.
    }
}
