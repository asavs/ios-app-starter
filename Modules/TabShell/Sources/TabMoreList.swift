import SwiftUI

/// More's list: the tabs a compact bar has no room for, each opening its destination in place.
struct TabMoreList<ID: Hashable & RawRepresentable>: View where ID.RawValue == String {
    let tabs: [TabItem<ID>]
    let open: (ID) -> Void

    var body: some View {
        NavigationStack {
            List(tabs) { tab in
                Button {
                    open(tab.id)
                } label: {
                    Label { Text(tab.title) } icon: { Image(systemName: tab.systemImage) }
                }
                .foregroundStyle(.primary)
                .badge(tab.badgeCount)
                .accessibilityIdentifier(TabShellIdentifiers.moreRow(tab.id.rawValue))
            }
            .navigationTitle(Text("More", bundle: .module))
        }
    }
}
