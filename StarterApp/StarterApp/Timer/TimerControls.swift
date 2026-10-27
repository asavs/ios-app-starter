import SwiftUI
#if canImport(SessionTimer)
import Theme

/// Start, pause or resume, plus Skip and Reset. Skip and Reset sit side by side, or stacked when
/// they don't fit, such as at the accessibility text sizes.
struct TimerControls: View {
    let model: TimerScreenModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.medium) {
            Button(action: model.primaryAction) {
                Text(model.primaryTitle).frame(maxWidth: .infinity)
            }
            .prominentButtonStyle()
            .accessibilityIdentifier("timer.primary")

            ViewThatFits {
                HStack(spacing: theme.spacing.medium) { TimerSecondaryButtons(model: model) }
                VStack(spacing: theme.spacing.medium) { TimerSecondaryButtons(model: model) }
            }
            .buttonStyle(.bordered)
            .controlSize(.large) // At least the 44-point minimum tap target.
        }
    }
}
#endif
