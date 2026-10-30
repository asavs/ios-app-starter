import Foundation
#if canImport(SessionTimer)
import SessionTimer

/// The template's two example sessions. An app replaces these with its own.
enum TimerPlan: String, CaseIterable, Identifiable {
    case intervals, focus

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .intervals: "Intervals"
        case .focus: "Focus"
        }
    }

    var workTitle: LocalizedStringResource {
        switch self {
        case .intervals: "Work"
        case .focus: "Focus"
        }
    }

    var restTitle: LocalizedStringResource {
        switch self {
        case .intervals: "Rest"
        case .focus: "Break"
        }
    }

    /// Used until someone edits the plan.
    var defaultTimes: PlanTimes {
        switch self {
        case .intervals: PlanTimes(work: 20, rest: 10, rounds: 3)
        case .focus: PlanTimes(work: 25 * 60, rest: 5 * 60, rounds: 4)
        }
    }

    /// Where this plan's edited times are stored.
    var storageKey: String { "timer.\(rawValue)" }

    func session(_ times: PlanTimes) -> SessionPlan {
        .intervals(work: SessionPhase(kind: "work", title: workTitle, duration: times.workDuration),
                   rest: SessionPhase(kind: "rest", title: restTitle, duration: times.restDuration),
                   rounds: times.rounds)
    }
}
#endif
