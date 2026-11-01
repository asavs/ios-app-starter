#if os(iOS)
import SwiftUI
import Theme

/// The Lock Screen banner (also StandBy, scaled by the system): the ring, the plan and phase, the
/// countdown, and the footer with the one button. Within the 160-point maximum height.
struct SessionLockScreenView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityState
    let isStale: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(spacing: theme.spacing.medium) {
                SessionRingView(state: state)
                    .frame(width: 44, height: 44)
                SessionPhaseLabel(attributes: attributes, state: state)
                SessionCountdownText(state: state, isStale: isStale)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .frame(minWidth: 72, alignment: .trailing)
            }
            SessionActivityFooter(attributes: attributes, state: state, isStale: isStale)
        }
        .padding(theme.spacing.medium)
        .accessibilityIdentifier("sessionActivity.lockScreen")
    }
}
#endif
