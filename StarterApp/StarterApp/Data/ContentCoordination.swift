import SwiftUI
#if canImport(Database) && canImport(Attachments)
import SwiftData

extension EnvironmentValues {
    /// The app's content coordinator, once the store is open; nil in previews without one.
    @Entry var contentCoordinator: ContentCoordinator?
}

/// Creates the app's one `ContentCoordinator` on the open store's main context, hands it to every
/// screen through the environment, and runs the pending file deletions once per launch, so a removal
/// interrupted last time finishes now.
struct ContentCoordination: ViewModifier {
    @Environment(\.modelContext) private var context
    @State private var coordinator: ContentCoordinator?

    func body(content: Content) -> some View {
        content
            .environment(\.contentCoordinator, coordinator)
            .task {
                let coordinator = coordinator ?? ContentCoordinator(context: context, store: StarterAttachments.store)
                self.coordinator = coordinator
                await coordinator.processPendingDeletions()
            }
    }
}
#endif
