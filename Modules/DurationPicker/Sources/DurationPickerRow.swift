import SwiftUI
import Theme

/// A form row for a length of time, laid out like the Clock app's timer: hours, minutes and
/// seconds wheels with their units fixed beside the selection. The row shows the title and the
/// value; tapping it opens the wheels below it, as a date row in Calendar does. The value always
/// stays inside `range` and on a `step`.
///
/// ```swift
/// Form {
///     DurationPickerRow("Work", value: $work)
///     DurationPickerRow("Rest", value: $rest, range: .seconds(5) ... .seconds(300), step: .seconds(5))
/// }
/// ```
///
/// Apple doesn't offer the Clock app's picker to other apps: `UIDatePicker`'s countdown mode shows
/// only hours and minutes. Native wheel pickers side by side give the same control, and VoiceOver
/// its standard adjustable wheels.
public struct DurationPickerRow: View {
    private let title: LocalizedStringResource
    @Binding private var value: Duration
    private let options: DurationOptions
    /// What the wheels show. It follows `value`, and a wheel change writes back a clamped `value`.
    @State private var parts: DurationOptions.Parts
    @State private var isExpanded = false
    @Environment(\.appTheme) private var theme

    /// - Parameters:
    ///   - range: The shortest and longest allowed value, within 0 to 23:59:59 like the Clock app.
    ///   - step: The seconds wheel's spacing, one second by default; it must divide a minute.
    public init(_ title: LocalizedStringResource, value: Binding<Duration>,
                range: ClosedRange<Duration> = .seconds(1) ... .seconds(DurationOptions.longest),
                step: Duration = .seconds(1)) {
        let options = DurationOptions(range: range, step: step)
        self.title = title
        _value = value
        self.options = options
        _parts = State(initialValue: options.split(options.clamped(value.wrappedValue)))
    }

    public var body: some View {
        let shown = options.clamped(value)
        Button(action: toggleWheels) {
            LabeledContent {
                Text(shown, format: .time(pattern: shown >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond))
                    .monospacedDigit()
                    .foregroundStyle(isExpanded ? theme.colors.accent : theme.colors.textSecondary)
            } label: {
                Text(title).foregroundStyle(theme.colors.textPrimary)
            }
        }
        .accessibilityValue(Text(shown.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))))
        .accessibilityHint(isExpanded ? Text("Hides the hours, minutes and seconds.", bundle: .module)
                                      : Text("Shows the hours, minutes and seconds.", bundle: .module))
        .onChange(of: value) { _, newValue in
            let matching = options.split(options.clamped(newValue))
            if matching != parts { parts = matching }
        }
        if isExpanded {
            HStack(spacing: 0) {
                if options.hours.isEmpty == false {
                    DurationWheel(values: options.hours, selection: $parts.hours,
                                  label: Text("Number of hours", bundle: .module), unit: Text("hours", bundle: .module))
                }
                DurationWheel(values: options.minutes, selection: $parts.minutes,
                              label: Text("Number of minutes", bundle: .module), unit: Text("min", bundle: .module))
                DurationWheel(values: options.seconds, selection: $parts.seconds,
                              label: Text("Number of seconds", bundle: .module), unit: Text("sec", bundle: .module))
            }
            // The row has no leading text, so start its separator at the edge like the others.
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .onChange(of: parts) { _, newParts in value = options.combined(newParts) }
        }
    }

    private func toggleWheels() {
        withAnimation { isExpanded.toggle() }
    }
}

#Preview {
    @Previewable @State var work = Duration.seconds(20)
    @Previewable @State var focus = Duration.seconds(25 * 60)
    Form {
        DurationPickerRow("Work", value: $work, range: .seconds(5) ... .seconds(600), step: .seconds(5))
        DurationPickerRow("Focus", value: $focus)
    }
}
