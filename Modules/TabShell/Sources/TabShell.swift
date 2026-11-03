import SwiftUI
import Theme

/// Native top-level navigation; the host supplies every label, symbol, badge, and destination view.
///
/// Put a separate `NavigationStack` inside each destination that needs hierarchical navigation.
/// Do not wrap the shell in a shared stack: each tab should keep its own navigation context.
///
/// The selection decides which tabs show and in what order (`TabSelection.tabs`); `tabs` describes
/// every destination the host can show, in any order, and may list more than the selection uses. A
/// host whose person chooses their tabs passes all of its descriptors once and changes only the
/// selection's list.
public struct TabShell<ID: Hashable & RawRepresentable, Content: View>: View where ID.RawValue == String {
    @Environment(\.appTheme) private var theme
    @Bindable private var selection: TabSelection<ID>
    private let items: [ID: TabItem<ID>]
    private let content: (ID) -> Content

    public init(tabs: [TabItem<ID>], selection: TabSelection<ID>,
                @ViewBuilder content: @escaping (ID) -> Content) {
        precondition(Set(tabs.map(\.id)).count == tabs.count, "Tab descriptors must have unique IDs")
        let items = Dictionary(uniqueKeysWithValues: tabs.map { ($0.id, $0) })
        precondition(selection.tabs.allSatisfy { items[$0] != nil },
                     "Every selected tab needs a descriptor: \(selection.tabs.map(\.rawValue))")
        self.items = items
        self.selection = selection
        self.content = content
    }

    /// The selection's tabs, in its order, with their descriptors. A selected tab without a
    /// descriptor can't be drawn and is left out; the initializer rejects that at the start.
    private var tabs: [TabItem<ID>] {
        let shown = selection.tabs.compactMap { items[$0] }
        assert(shown.count == selection.tabs.count, "A selected tab has no descriptor")
        return shown
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
