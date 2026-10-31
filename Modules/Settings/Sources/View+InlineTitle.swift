import SwiftUI

extension View {
    /// An inline navigation title on iOS; macOS has no title display modes, and the package builds
    /// there so `swift test` runs on the host.
    @ViewBuilder func inlineNavigationTitle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
#else
        self
#endif
    }
}
