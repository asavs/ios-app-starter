import SwiftUI
#if canImport(SessionTimer) && canImport(TimerRing)
import SessionTimer
import Theme
import TimerRing

/// The template's timer: the SessionTimer and TimerRing modules configured as short intervals or
/// as a Pomodoro-style focus session. `TimerScreenModel` holds the logic.
struct StarterTimerView: View {
#if canImport(SessionActivity)
    @State private var model = TimerScreenModel(defaults: StarterDefaults.store, activity: .shared)
#else
    @State private var model = TimerScreenModel(defaults: StarterDefaults.store)
#endif
    @State private var isEditing = false
#if canImport(Database)
    @State private var isChoosingPreset = false
#endif
    @Environment(\.appTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

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
                .accessibilityIdentifier(Identifiers.Timer.plan)

                TimerRing(fractionRemaining: snapshot.phaseFractionRemaining,
                          title: snapshot.status == .finished ? "Done" : phase.title,
                          remaining: snapshot.phaseRemaining,
                          tint: phase.kind == "rest" ? theme.colors.success : theme.colors.accent)
                    .frame(maxWidth: 320)
                    .accessibilityIdentifier(Identifiers.Timer.ring)

                Text("Step \(snapshot.phaseIndex + 1) of \(model.timer.plan.phases.count)")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .accessibilityIdentifier(Identifiers.Timer.step)

                TimerControls(model: model)
#if canImport(SessionActivity)
                if SessionActivityReadout.isRequested {
                    SessionActivityReadout(snapshot: snapshot)
                }
#endif
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
                    .accessibilityIdentifier(Identifiers.Timer.presets)
#endif
                Button("Edit", action: edit)
                    .disabled(model.canChangePlan == false)
                    .accessibilityIdentifier(Identifiers.Timer.edit)
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
        // The Live Activity's button may have paused or resumed the session while the app was away.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.restoreFromRecord() }
        }
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
