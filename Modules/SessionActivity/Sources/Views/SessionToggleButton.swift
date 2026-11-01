#if os(iOS)
import AppIntents
import SwiftUI
import Theme

/// Pause or Resume, performed by `ToggleSessionIntent` in the app's process. Inactive on a locked
/// device until the person unlocks, as the system requires.
struct SessionToggleButton: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityState
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(intent: ToggleSessionIntent(sessionID: attributes.sessionID)) {
            if state.status == .paused {
                Label { Text("Resume", bundle: .module) } icon: { Image(systemName: "play.fill") }
            } else {
                Label { Text("Pause", bundle: .module) } icon: { Image(systemName: "pause.fill") }
            }
        }
        .buttonStyle(.bordered)
        .tint(theme.colors.accent)
        .accessibilityIdentifier("sessionActivity.toggle")
    }
}
#endif
