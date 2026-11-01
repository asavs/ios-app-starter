#if os(iOS)
import SwiftUI
import Theme

/// When the session ends, or why the countdown stopped, with the pause/resume button. The button
/// is the activity's one interactive element (HIG: prefer a single one).
struct SessionActivityFooter: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityState
    let isStale: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.small) {
            SessionEndLabel(state: state, isStale: isStale)
            Spacer(minLength: theme.spacing.small)
            if state.status != .finished {
                SessionToggleButton(attributes: attributes, state: state)
            }
        }
    }
}
#endif
