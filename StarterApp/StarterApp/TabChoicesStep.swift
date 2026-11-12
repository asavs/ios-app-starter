import SwiftUI
#if canImport(TabShell) && canImport(Onboarding)
import Theme // Onboarding depends on Theme, so it is here whenever this step is.

/// Onboarding's optional Choose your tabs step: every feature this build has, one sentence each, on or
/// off. The same choice as Settings' chooser (`FeatureChoices.shared`), so a change applies as it is
/// made and shows in the tab bar under the sheet.
///
/// Showing the step writes nothing: a fresh install that skips it keeps the defaults, and a replay
/// shows, and keeps, the stored choice. Order is changed in Settings; turning a tab on puts it back
/// where the default order has it (`FeatureChoices.include`).
struct TabChoicesStep: View {
    @State private var choices = FeatureChoices.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.large) {
                VStack(spacing: theme.spacing.small) {
                    Text("Choose your tabs")
                        .font(theme.typography.title)
                        .foregroundStyle(theme.colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Turn off what you won't use. You can change this, and the order, in Settings.")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .multilineTextAlignment(.center)
                VStack(spacing: theme.spacing.small) {
                    ForEach(StarterFeature.available) { feature in
                        TabChoicesStepRow(feature: feature, isOn: choices.chosen.contains(feature.id)) {
                            toggle(feature)
                        }
                    }
                }
            }
            .padding(.horizontal, theme.spacing.large)
            .padding(.top, theme.spacing.extraLarge)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicatorsFlash(onAppear: true) // At large text sizes, shows there is more below the page dots.
        .sensoryFeedback(.selection, trigger: choices.chosen)
    }

    private func toggle(_ feature: StarterFeature) {
        if choices.chosen.contains(feature.id) {
            choices.hide(feature.id)
        } else {
            choices.include(feature.id)
        }
    }
}

#Preview {
    TabChoicesStep()
}
#endif
