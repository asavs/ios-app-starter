import SwiftData
import SwiftUI

/// Shows the app with its container once the store is open, or the recovery screen until it is.
///
/// ```swift
/// WindowGroup {
///     DatabaseGate(loader) { ContentView() }
/// }
/// ```
public struct DatabaseGate<Content: View>: View {
    private let loader: DatabaseLoader
    private let content: Content

    public init(_ loader: DatabaseLoader, @ViewBuilder content: () -> Content) {
        self.loader = loader
        self.content = content()
    }

    public var body: some View {
        switch loader.status {
        case .ready(let container):
            content.modelContainer(container)
        case .failed(let error):
            DatabaseRecoveryView(loader: loader, error: error)
        }
    }
}
