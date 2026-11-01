#if os(iOS)
import ActivityKit
import SwiftUI
import Theme
import WidgetKit

/// The session's Live Activity: the Lock Screen banner and the Dynamic Island's compact, minimal
/// and expanded presentations. List it in the app's widget extension bundle:
///
/// ```swift
/// @main struct StarterWidgets: WidgetBundle {
///     var body: some Widget { SessionActivityWidget() }
/// }
/// ```
///
/// The views draw only what the state holds; the system counts the running phase down itself.
/// Every presentation deep-links to `SessionActivityAttributes.link`.
public struct SessionActivityWidget: Widget {
    @Environment(\.appTheme) private var theme

    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            SessionLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SessionRingView(state: context.state)
                        .frame(width: 44, height: 44)
                        .padding(.leading, theme.spacing.extraSmall)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SessionCountdownText(state: context.state, isStale: context.isStale)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    SessionPhaseLabel(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionActivityFooter(attributes: context.attributes, state: context.state, isStale: context.isStale)
                }
            } compactLeading: {
                SessionRingView(state: context.state)
                    .frame(width: 24, height: 24)
                    .padding(.leading, theme.spacing.extraSmall)
            } compactTrailing: {
                SessionCountdownText(state: context.state, isStale: context.isStale)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(width: 52)
                    .padding(.trailing, theme.spacing.extraSmall)
            } minimal: {
                SessionRingView(state: context.state)
                    .frame(width: 24, height: 24)
            }
            .widgetURL(context.attributes.link)
            .keylineTint(theme.colors.accent)
        }
    }
}

#Preview("Lock Screen", as: .content, using: SessionActivityAttributes.preview) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityState.previewRunning
    SessionActivityState.previewPaused
    SessionActivityState.previewFinished
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: SessionActivityAttributes.preview) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityState.previewRunning
    SessionActivityState.previewPaused
}

#Preview("Compact", as: .dynamicIsland(.compact), using: SessionActivityAttributes.preview) {
    SessionActivityWidget()
} contentStates: {
    SessionActivityState.previewRunning
    SessionActivityState.previewPaused
}
#endif
