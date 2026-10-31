import SwiftUI
#if canImport(SessionTimer) && canImport(TimerRing)
import SessionTimer
import Theme
import TimerRing

/// The template's timer: the SessionTimer and TimerRing modules configured as short intervals or
/// as a Pomodoro-style focus session. `TimerScreenModel` holds the logic.
struct StarterTimerView: View {
    @State private var model = TimerScreenModel()
    @State private var isEditing = false
#if canImport(Database)
    @State private var isChoosingPreset = false
#endif
    @Environment(\.appTheme) private var theme

    var body: some View {
        let snapshot = model.timer.snapshot
        let phase = model.timer.plan.phases[snapshot.phaseIndex]
        ScrollView {
            VStack(spacing: theme.spacing.large) {
                Picker("Plan", selection: $model.plan) {
                    ForEach(TimerPlan.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(model.canChangePlan == false)
                .accessibilityIdentifier("timer.plan")

                TimerRing(fractionRemaining: snapshot.phaseFractionRemaining,
                          title: snapshot.status == .finished ? "Done" : phase.title,
                          remaining: snapshot.phaseRemaining,
                          tint: phase.kind == "rest" ? theme.colors.success : theme.colors.accent)
                    .frame(maxWidth: 320)
                    .accessibilityIdentifier("timer.ring")

                Text("Step \(snapshot.phaseIndex + 1) of \(model.timer.plan.phases.count)")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .accessibilityIdentifier("timer.step")

                TimerControls(model: model)
            }
            .padding()
        }
        .background(theme.colors.background)
        .navigationTitle("Timer")
#if canImport(DurationPicker)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
#if canImport(Database)
                // Saved plans live in the database module's store.
                Button("Presets", systemImage: "bookmark", action: choosePreset)
                    .accessibilityIdentifier("timer.presets")
#endif
                Button("Edit", action: edit)
                    .disabled(model.canChangePlan == false)
                    .accessibilityIdentifier("timer.edit")
            }
        }
        .sheet(isPresented: $isEditing) {
            TimerPlanEditor(plan: model.plan, times: $model.times)
        }
#if canImport(Database)
        .sheet(isPresented: $isChoosingPreset) {
            TimerPresetsView(model: model)
        }
#endif
#endif
        .onChange(of: snapshot, model.sessionChanged)
        // A tap for starting, each new phase and finishing, unless haptics are off in Settings.
        .sensoryFeedback(trigger: snapshot, model.haptic)
        // The screen stays on only while a session runs on this screen.
        .onChange(of: model.isRunning, initial: true) { _, running in
            UIApplication.shared.isIdleTimerDisabled = running
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func edit() {
        isEditing = true
    }

#if canImport(Database)
    private func choosePreset() {
        isChoosingPreset = true
    }
#endif
}

#Preview {
    NavigationStack { StarterTimerView() }
}
#endif
