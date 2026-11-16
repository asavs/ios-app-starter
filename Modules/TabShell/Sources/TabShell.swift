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
/// selection's list. Reordering the list resets the destinations' view state, such as a navigation
/// stack the destination owns; keep what must survive above the shell.
///
/// At compact width with more than five tabs, the bar shows four and a More tab listing the rest
/// (`TabOverflow`). Apply `tabShellMoreButton()` to each destination's root inside its stack: it is
/// that destination's way back to the list when it was opened from More.
public struct TabShell<ID: Hashable & RawRepresentable, Content: View>: View where ID.RawValue == String {
    @Environment(\.appTheme) private var theme
    @Bindable private var selection: TabSelection<ID>
    private let items: [ID: TabItem<ID>]
    private let content: (ID) -> Content
    /// Counts reorders. See `body`.
    @State private var reorders = 0
    /// More's list shows instead of the tab picked from it: More was picked, or its back button.
    @State private var showsMoreList = false
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

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

    /// The tabs in the bar and those in More (`TabOverflow`).
    private var split: (bar: [TabItem<ID>], more: [TabItem<ID>]) {
        TabOverflow.split(tabs, compact: isCompact)
    }

    private var isCompact: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    /// The tab view's selection: the selected tab, or More while its list shows or while the
    /// selected tab is one of More's. Picking a tab selects it; picking More shows the list.
    private var slot: Binding<TabSlot<ID>> {
        Binding {
            let more = split.more
            guard !more.isEmpty else { return .tab(selection.selectedTab) } // No More to show.
            return showsMoreList || more.contains { $0.id == selection.selectedTab } ? .more : .tab(selection.selectedTab)
        } set: { slot in
            switch slot {
            case .tab(let id): selection.selectedTab = id
            case .more: showsMoreList = true
            }
        }
    }

    public var body: some View {
        let (bar, more) = split
        Group {
            if #available(iOS 18, macOS 15, *) {
                TabView(selection: slot) {
                    ForEach(bar) { tab in
                        Tab(value: TabSlot.tab(tab.id)) {
                            content(tab.id)
                        } label: {
                            label(tab)
                        }
                        .badge(tab.badgeCount)
                        .accessibilityIdentifier(tab.accessibilityIdentifier)
                    }
                    if !more.isEmpty {
                        Tab(value: TabSlot.more) {
                            moreDestination(more)
                        } label: {
                            moreLabel
                        }
                        .badge(more.reduce(0) { $0 + $1.badgeCount })
                        .accessibilityIdentifier(TabShellIdentifiers.more)
                    }
                }
            } else {
                // The Tab API starts at iOS 18 / macOS 15. Keep the native iOS 17 presentation.
                TabView(selection: slot) {
                    ForEach(bar) { tab in
                        content(tab.id)
                            .tabItem {
                                label(tab)
                                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                            }
                            .tag(TabSlot.tab(tab.id))
                            .badge(tab.badgeCount)
                    }
                    if !more.isEmpty {
                        moreDestination(more)
                            .tabItem {
                                moreLabel
                                    .accessibilityIdentifier(TabShellIdentifiers.more)
                            }
                            .tag(TabSlot<ID>.more)
                            .badge(more.reduce(0) { $0 + $1.badgeCount })
                    }
                }
            }
        }
        // After tabs swap places, iOS 27.0 draws a moved tab with another tab's symbol, with `Tab` and
        // `tabItem` alike, and no later change of the label corrects it. A new tab view draws them
        // right, so a reorder builds one. The destinations' view state goes with it, which is why
        // this happens only for a reorder: tabs coming and going keep theirs. More coming or going
        // does the same to the bar's buttons (the button that was More kept its identifier with
        // Settings' label), so that builds a new one too.
        .id(TabViewIdentity(reorders: reorders, overflows: !more.isEmpty))
        .onChange(of: selection.tabs) { old, new in
            if TabOrder.isReorder(from: old, to: new) { reorders += 1 }
        }
        // A link or shortcut that selects a tab leaves More's list, even for the tab already selected.
        .onChange(of: selection.requests) { showsMoreList = false }
        .tint(theme.colors.accent)
        // Native bars own their material, safe areas, selected traits, and motion preferences.
    }

    private func label(_ tab: TabItem<ID>) -> some View {
        Label { Text(tab.title) } icon: { Image(systemName: tab.systemImage) }
    }

    private var moreLabel: some View {
        Label { Text("More", bundle: .module) } icon: { Image(systemName: "ellipsis") }
    }

    /// More's list, or the tab picked from it with a way back to the list in its environment. The
    /// destination replaces the list rather than being pushed onto a stack of the shell's, so its own
    /// navigation stack is the only one.
    @ViewBuilder
    private func moreDestination(_ more: [TabItem<ID>]) -> some View {
        if !showsMoreList, more.contains(where: { $0.id == selection.selectedTab }) {
            content(selection.selectedTab)
                .id(selection.selectedTab)
                .environment(\.showMoreList, ShowMoreListAction { showsMoreList = true })
        } else {
            TabMoreList(tabs: more) { selection.selectedTab = $0 }
        }
    }
}
