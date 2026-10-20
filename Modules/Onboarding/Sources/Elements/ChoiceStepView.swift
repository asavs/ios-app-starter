import SwiftUI
import Theme

/// The choice step: the question, a hint saying how many answers it takes, and one row per option.
/// Rows are buttons with the selected trait, so VoiceOver reads "Selected" on picked answers.
/// The flow owns the selection and the Continue button. Scrolls when Dynamic Type needs the room.
public struct ChoiceStepView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var symbolWidth: CGFloat = 32
    private let choice: OnboardingChoice
    @Binding private var selection: Set<String>

    public init(_ choice: OnboardingChoice, selection: Binding<Set<String>>) {
        self.choice = choice
        _selection = selection
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.large) {
                VStack(spacing: theme.spacing.small) {
                    Text(choice.title)
                        .font(theme.typography.title)
                        .foregroundStyle(theme.colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let message = choice.message {
                        Text(message)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    Text(choice.mode == .single ? "Choose one" : "Choose any that apply")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .multilineTextAlignment(.center)
                VStack(spacing: theme.spacing.small) {
                    ForEach(choice.options) { option in
                        row(option)
                    }
                }
            }
            .padding(.horizontal, theme.spacing.large)
            .padding(.top, theme.spacing.extraLarge)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func row(_ option: OnboardingChoice.Option) -> some View {
        let isSelected = selection.contains(option.id)
        return Button {
            selection = choice.selection(selection, tapping: option.id)
        } label: {
            HStack(spacing: theme.spacing.medium) {
                if let systemImage = option.systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(theme.colors.accent)
                        .frame(width: symbolWidth) // A fixed column, so titles line up whatever the symbol's width.
                        .accessibilityHidden(true)
                }
                Text(option.title)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: indicator(isSelected: isSelected))
                    .font(.title3)
                    .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(theme.spacing.medium)
            .frame(minHeight: 44)
            .background(theme.colors.surface, in: .rect(cornerRadius: theme.radii.medium))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radii.medium)
                    .strokeBorder(theme.colors.accent, lineWidth: isSelected ? 2 : 0)
            }
            .contentShape(.rect(cornerRadius: theme.radii.medium))
            .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.choice.\(choice.id).\(option.id)")
    }

    /// A circle for a single choice and a square for a multiple one, the system's radio and checkbox cues.
    private func indicator(isSelected: Bool) -> String {
        switch choice.mode {
        case .single: isSelected ? "checkmark.circle.fill" : "circle"
        case .multiple: isSelected ? "checkmark.square.fill" : "square"
        }
    }
}

#Preview("Choice") {
    @Previewable @State var selection: Set<String> = ["tool"]
    ChoiceStepView(OnboardingChoice(id: "goal", title: "What will you build?", options: [
        .init(id: "tool", title: "A tool for myself", systemImage: "hammer"),
        .init(id: "friends", title: "Something for friends", systemImage: "person.2"),
    ], mode: .multiple), selection: $selection)
}
