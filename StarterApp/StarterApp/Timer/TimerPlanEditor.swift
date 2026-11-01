import SwiftUI
#if canImport(SessionTimer) && canImport(DurationPicker)
import DurationPicker

/// The Edit sheet: the chosen plan's phase lengths and rounds.
struct TimerPlanEditor: View {
    let plan: TimerPlan
    @Binding var times: PlanTimes
    @Environment(\.dismiss) private var dismiss

    /// Five seconds up to the Clock app's 23:59:59.
    private static let phaseRange = Duration.seconds(5) ... .seconds(DurationOptions.longest)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DurationPickerRow(plan.workTitle, value: $times.workDuration, range: Self.phaseRange)
                        .accessibilityIdentifier(Identifiers.Timer.Edit.work)
                    DurationPickerRow(plan.restTitle, value: $times.restDuration, range: Self.phaseRange)
                        .accessibilityIdentifier(Identifiers.Timer.Edit.rest)
                    Stepper(value: $times.rounds, in: PlanTimes.roundRange) {
                        Text("Rounds: \(times.rounds)")
                    }
                    .accessibilityIdentifier(Identifiers.Timer.Edit.rounds)
                } footer: {
                    Text("Rests come between rounds, not after the last one.")
                }
            }
            .navigationTitle(Text(plan.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                        .accessibilityIdentifier(Identifiers.Timer.Edit.done)
                }
            }
        }
    }

    private func close() {
        dismiss()
    }
}
#endif
