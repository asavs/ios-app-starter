import SwiftUI
import Theme

/// One column of `DurationPickerRow`: a wheel of numbers with its unit fixed to the right of the
/// selection, as in the Clock app.
struct DurationWheel: View {
    let values: [Int]
    @Binding var selection: Int
    /// What VoiceOver calls the wheel, such as "Number of minutes".
    let label: Text
    /// The unit shown beside the selection, such as "min". VoiceOver reads `label` instead.
    let unit: Text

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.extraSmall) {
            Picker(selection: $selection) {
                ForEach(values, id: \.self) { number in
                    Text(number, format: .number)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } label: {
                label
            }
            .wheelPickerStyle()
            .labelsHidden()
            unit
                .font(theme.typography.body)
                .bold()
                .foregroundStyle(theme.colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        // Side-by-side wheels otherwise share touches past their edges.
        .clipped()
        .contentShape(.rect)
    }
}

private extension View {
    /// Wheels on iOS; the package also builds for macOS so `swift test` runs on the host.
    @ViewBuilder func wheelPickerStyle() -> some View {
#if os(iOS)
        pickerStyle(.wheel)
#else
        self
#endif
    }
}
