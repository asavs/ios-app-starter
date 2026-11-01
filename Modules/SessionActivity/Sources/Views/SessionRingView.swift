#if os(iOS)
import SwiftUI
import Theme

/// One ring that empties as the phase runs out: the system animates it while running; it holds
/// still while paused. Rest phases use the theme's success colour, like the Timer tab's ring.
struct SessionRingView: View {
    let state: SessionActivityState
    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if state.status == .running, let phase = state.phase {
                ProgressView(timerInterval: phase, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
            } else {
                ProgressView(value: state.pausedFractionRemaining) { EmptyView() } currentValueLabel: { EmptyView() }
            }
        }
        .progressViewStyle(.circular)
        .tint(state.phaseKind == "rest" ? theme.colors.success : theme.colors.accent)
        .accessibilityHidden(true) // The countdown text beside it says the same.
    }
}
#endif
