import SwiftUI

extension View {
    /// Adds a back button to More's list while this destination was opened from More. Apply it to
    /// the root view inside each destination's `NavigationStack`: the destination's own stack owns
    /// the navigation bar, so only a view inside it can put a button there. Elsewhere it adds nothing.
    public func tabShellMoreButton() -> some View {
        modifier(MoreButtonModifier())
    }
}

private struct MoreButtonModifier: ViewModifier {
    @Environment(\.showMoreList) private var showMoreList

    func body(content: Content) -> some View {
        content.toolbar {
            if let showMoreList {
                ToolbarItem(placement: .navigation) {
                    Button {
                        showMoreList()
                    } label: {
                        Label { Text("More", bundle: .module) } icon: { Image(systemName: "chevron.backward") }
                    }
                    .accessibilityIdentifier(TabShellIdentifiers.moreBack)
                }
            }
        }
    }
}

