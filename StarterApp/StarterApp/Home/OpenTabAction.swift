import SwiftUI
#if canImport(TabShell)

/// Selects one of the chosen tabs from inside another: Home's shortcuts and See All buttons.
/// `StarterTabsView` provides it; outside a shell it does nothing.
struct OpenTabAction: Sendable {
    private let action: @MainActor @Sendable (StarterTab) -> Void

    init(_ action: @escaping @MainActor @Sendable (StarterTab) -> Void) {
        self.action = action
    }

    @MainActor func callAsFunction(_ tab: StarterTab) {
        action(tab)
    }
}

extension EnvironmentValues {
    @Entry var openTab = OpenTabAction { _ in }
}
#endif
