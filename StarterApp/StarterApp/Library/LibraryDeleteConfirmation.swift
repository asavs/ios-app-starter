import SwiftUI
#if canImport(Database) && canImport(Attachments)

extension View {
    /// Asks before deleting a Library item, as a confirmation dialog: the person chose Delete, so
    /// the dialog offers the choice again with Cancel, and says how many notes refer to the item when
    /// any do. The coordinator deletes: references go, the notes' text stays, the file goes once
    /// nothing else owns it. `onDeleted` runs after a successful delete (a detail screen dismisses).
    func libraryDeleteConfirmation(item: Binding<LibraryItem?>, onDeleted: (() -> Void)? = nil) -> some View {
        modifier(LibraryDeleteConfirmation(item: item, onDeleted: onDeleted))
    }
}

/// Identifiers: `library.delete.confirm`.
struct LibraryDeleteConfirmation: ViewModifier {
    @Binding var item: LibraryItem?
    let onDeleted: (() -> Void)?
    @Environment(\.contentCoordinator) private var coordinator
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Delete this item?", isPresented: $item.isSome(), titleVisibility: .visible, presenting: item) { item in
                Button("Delete", role: .destructive) { delete(item) }
                    .accessibilityIdentifier(Identifiers.Library.deleteConfirm)
                Button("Cancel", role: .cancel) {}
            } message: { item in
                if let count = references(to: item), count > 0 {
                    Text("Used in ^[\(count) notes](inflect: true). Deleting it removes it from those notes. Their text stays.")
                }
            }
            .alert("Couldn't Delete", isPresented: $failure.isSome()) {
                Button("OK") {}
            } message: {
                Text(verbatim: failure ?? "")
            }
    }

    private func references(to item: LibraryItem) -> Int? {
        try? coordinator?.referenceCount(to: item)
    }

    private func delete(_ item: LibraryItem) {
        guard let coordinator else { return }
        do {
            try coordinator.deleteLibraryItem(item)
            onDeleted?()
        } catch {
            failure = error.localizedDescription // The item and its file are as they were.
        }
    }
}
#endif
