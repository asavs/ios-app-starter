import SwiftUI
#if canImport(TabShell) && canImport(Onboarding)
import Theme

/// One feature in onboarding's tab step, drawn like the choice step's answers: symbol, name and one
/// sentence, and a circle that fills when the tab is on. A button with the selected trait, so
/// VoiceOver reads "Selected" on the tabs that show. A required feature can't be turned off: its row
/// says it is always shown, and a tap leaves it on.
struct TabChoicesStepRow: View {
    let feature: StarterFeature
    let isOn: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var symbolWidth: CGFloat = 32

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.medium) {
                // At the accessibility sizes the symbol column leaves the text a few letters a line.
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: feature.systemImage)
                        .font(.title3)
                        .foregroundStyle(theme.colors.accent)
                        .frame(width: symbolWidth)
                        .accessibilityHidden(true) // The name says it.
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(feature.summary)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                    if feature.isRequired {
                        Text("Always shown")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: indicator)
                    .font(.title3)
                    .foregroundStyle(isOn ? theme.colors.accent : theme.colors.textSecondary)
                    .accessibilityHidden(true) // The selected trait says it.
            }
            .padding(theme.spacing.medium)
            .frame(minHeight: 44)
            .background(theme.colors.surface, in: .rect(cornerRadius: theme.radii.medium))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.medium)
                    .strokeBorder(theme.colors.accent, lineWidth: isOn ? 2 : 0)
            }
            .contentShape(.rect(cornerRadius: theme.radii.medium))
            .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        // Not `.disabled`: that dims the row below readable contrast. A tap on a required feature
        // changes nothing (`FeatureChoices.hide` ignores it), and "Always shown" says why.
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(Identifiers.TabChoices.onboarding(feature.id.rawValue))
    }

    /// A lock on the row that can't change, so the locked row doesn't read as an unanswered one.
    private var indicator: String {
        if feature.isRequired { "lock.circle.fill" } else if isOn { "checkmark.circle.fill" } else { "circle" }
    }
}
#endif
