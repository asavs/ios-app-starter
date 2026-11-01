import Foundation
#if canImport(SessionTimer) && canImport(Database)

extension TimerScreenModel {
    /// Loads a preset's plan and times. Does nothing while a session is underway.
    func apply(_ preset: TimerPreset) {
        guard canChangePlan else { return }
        plan = TimerPlan(rawValue: preset.plan) ?? .intervals
        times = PlanTimes(work: preset.work, rest: preset.rest, rounds: preset.rounds)
    }

    /// The current plan and times as a new preset.
    func preset(named name: String) -> TimerPreset {
        TimerPreset(name: name, plan: plan.rawValue, work: Int(times.workDuration.components.seconds),
                    rest: Int(times.restDuration.components.seconds), rounds: times.rounds)
    }
}
#endif
