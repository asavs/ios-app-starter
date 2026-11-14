import SwiftUI
#if canImport(TabShell) && canImport(Database) && canImport(Attachments)
import SwiftData
import Theme

/// Home's newest Library items, in the Library tab's order, each opening its detail here on Home.
/// With nothing collected yet it says so and offers the Library tab, where Add imports. See All
/// switches to that tab too.
struct RecentLibrarySection: View {
    static let limit = 3

    @Query(RecentLibrarySection.recent) private var items: [LibraryItem]
    @State private var opened: UUID?
    @Environment(\.openTab) private var openTab

    private static var recent: FetchDescriptor<LibraryItem> {
        var descriptor = FetchDescriptor<LibraryItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return descriptor
    }

    var body: some View {
        HomeSection(tab: .library, title: "Recently Collected", seeAll: items.isEmpty ? nil : .library) {
            if items.isEmpty {
                HomeEmptyCard(message: "Nothing collected yet. Photos, files and links you add to your Library show here.",
                              actionTitle: "Open Library", systemImage: "books.vertical",
                              identifier: Identifiers.Home.libraryEmpty, actionIdentifier: Identifiers.Home.openLibrary) {
                    openTab(.library)
                }
            } else {
                ForEach(items) { item in
                    if item.id != items.first?.id {
                        Divider()
                    }
                    Button { opened = item.id } label: {
                        HomeRow(systemImage: item.kindSymbol, title: Text(verbatim: item.displayTitle),
                                detail: Text(verbatim: item.kindName))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(Identifiers.Home.item(item.id.uuidString))
                }
            }
        }
        .navigationDestination(item: $opened, destination: detail)
    }

    @ViewBuilder
    private func detail(_ id: UUID) -> some View {
        if let item = items.first(where: { $0.id == id }) {
            LibraryItemView(item: item)
        } else {
            Color.clear
        }
    }
}
#endif
