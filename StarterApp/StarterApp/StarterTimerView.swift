import SwiftUI
#if canImport(SessionTimer) && canImport(TimerRing)
import SessionTimer
import Theme
import TimerRing

/// The template's timer: the same two modules configured as short intervals or as a Pomodoro-style
/// focus session. An app replaces `Plan` with its own sessions.
struct StarterTimerView: View {
    enum Plan: String, CaseIterable, Identifiable {
        case intervals, focus

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .intervals: "Intervals"
            case .focus: "Focus"
            }
        }

        var session: SessionPlan {
            switch self {
            case .intervals:
                .intervals(work: SessionPhase(kind: "work", title: "Work", duration: .seconds(20)),
                           rest: SessionPhase(kind: "rest", title: "Rest", duration: .seconds(10)), rounds: 3)
            case .focus:
                .intervals(work: SessionPhase(kind: "work", title: "Focus", duration: .seconds(25 * 60)),
                           rest: SessionPhase(kind: "rest", title: "Break", duration: .seconds(5 * 60)), rounds: 4)
            }
        }
    }

    @State private var plan = Plan.intervals
    @State private var timer = SessionTimer(plan: Plan.intervals.session)
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let snapshot = timer.snapshot
        let phase = timer.plan.phases[snapshot.phaseIndex]
        ScrollView {
            VStack(spacing: theme.spacing.large) {
                Picker("Plan", selection: $plan) {
                    ForEach(Plan.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                // Changing the plan starts over, so it waits until a session isn't underway.
                .disabled(snapshot.status == .running || snapshot.status == .paused)
                .accessibilityIdentifier("timer.plan")

                TimerRing(fractionRemaining: snapshot.phaseFractionRemaining,
                          title: snapshot.status == .finished ? "Done" : phase.title,
                          remaining: snapshot.phaseRemaining,
                          tint: phase.kind == "rest" ? theme.colors.success : theme.colors.accent)
                    .frame(maxWidth: 320)
                    .accessibilityIdentifier("timer.ring")

                Text("Step \(snapshot.phaseIndex + 1) of \(timer.plan.phases.count)")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
                    .accessibilityIdentifier("timer.step")

                controls(for: snapshot.status)
            }
            .padding()
        }
        .background(theme.colors.background)
        .navigationTitle("Timer")
        .onChange(of: plan) { _, plan in timer.load(plan.session) }
        // A tap on every phase change and on finishing; nothing for resets or plan changes.
        .sensoryFeedback(trigger: snapshot) { old, new in
            if new.status == .finished, old.status != .finished { return .success }
            if new.status == .running, new.phaseIndex != old.phaseIndex { return .impact }
            return nil
        }
        // The screen stays on only while a session runs on this screen.
        .onChange(of: snapshot.status == .running, initial: true) { _, running in
            UIApplication.shared.isIdleTimerDisabled = running
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func controls(for status: SessionSnapshot.Status) -> some View {
        VStack(spacing: theme.spacing.medium) {
            Button {
                switch status {
                case .running: timer.pause()
                case .finished:
                    timer.reset()
                    timer.start()
                case .ready, .paused: timer.start()
                }
            } label: {
                Text(primaryTitle(for: status)).frame(maxWidth: .infinity)
            }
            .prominentButtonStyle()
            .accessibilityIdentifier("timer.primary")

            // Side by side, or stacked at accessibility text sizes so neither label wraps.
            let secondary = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: theme.spacing.medium))
                : AnyLayout(HStackLayout(spacing: theme.spacing.medium))
            secondary {
                Button("Skip", systemImage: "forward.end") { timer.skipToNextPhase() }
                    .disabled(status == .ready || status == .finished)
                    .accessibilityIdentifier("timer.skip")
                Button("Reset", systemImage: "arrow.counterclockwise") { timer.reset() }
                    .disabled(status == .ready)
                    .accessibilityIdentifier("timer.reset")
            }
            .buttonStyle(.bordered)
        }
    }

    private func primaryTitle(for status: SessionSnapshot.Status) -> LocalizedStringResource {
        switch status {
        case .ready: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .finished: "Start again"
        }
    }
}

#Preview {
    NavigationStack { StarterTimerView() }
}
#endif
