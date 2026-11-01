import SwiftUI
#if canImport(SessionTimer) && canImport(Database)
import Theme

/// A preset's name with its plan and times, read by VoiceOver as one element.
struct TimerPresetRow: View {
    let preset: TimerPreset
    @Environment(\.appTheme) private var theme

    var body: some View {
        LabeledContent {
            HStack(spacing: theme.spacing.small) {
#if canImport(Attachments)
                if !preset.attachments.isEmpty {
                    Label("\(preset.attachments.count) attachments", systemImage: "paperclip")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(theme.colors.textSecondary)
                }
#endif
                Text(verbatim: summary)
                    .monospacedDigit()
            }
        } label: {
            Text(verbatim: preset.name)
                .foregroundStyle(theme.colors.textPrimary)
            Text((TimerPlan(rawValue: preset.plan) ?? .intervals).title)
        }
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        let work = Duration.seconds(preset.work).formatted(.time(pattern: .minuteSecond))
        let rest = Duration.seconds(preset.rest).formatted(.time(pattern: .minuteSecond))
        return "\(work) / \(rest) × \(preset.rounds)"
    }
}
#endif
