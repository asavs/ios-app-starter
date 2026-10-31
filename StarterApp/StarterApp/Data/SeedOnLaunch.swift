import SwiftUI
#if canImport(Database)
import SwiftData

/// Runs the template's seed once the container is in the environment.
struct SeedOnLaunch: ViewModifier {
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.task { seed() }
    }

    private func seed() {
        do {
            try StarterDatabase.seedIfNeeded(in: context)
        } catch {
            // The seed is sample content; the app works without it.
            assertionFailure("Seeding failed: \(error)")
        }
    }
}
#endif
