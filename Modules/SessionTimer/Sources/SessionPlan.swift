import Foundation

/// The ordered phases of one session. A workout, a Pomodoro and a meditation are each one plan.
public struct SessionPlan: Sendable {
    public let phases: [SessionPhase]
    public let totalDuration: Duration

    public init(phases: [SessionPhase]) {
        precondition(!phases.isEmpty, "A session needs at least one phase")
        self.phases = phases
        totalDuration = phases.reduce(.zero) { $0 + $1.duration }
    }

    /// `rounds` of `work`, with `rest` between rounds but not after the last, so a session ends on
    /// work rather than on dead time.
    public static func intervals(work: SessionPhase, rest: SessionPhase?, rounds: Int) -> SessionPlan {
        precondition(rounds > 0, "A session needs at least one round")
        var phases: [SessionPhase] = []
        for round in 1...rounds {
            phases.append(work)
            if let rest, round < rounds { phases.append(rest) }
        }
        return SessionPlan(phases: phases)
    }

    /// When phase `index` starts, measured from the start of the session.
    func start(ofPhase index: Int) -> Duration {
        phases[..<index].reduce(.zero) { $0 + $1.duration }
    }
}
