import Foundation

/// One timed step of a session, such as a hold, a rest or a focus block.
public struct SessionPhase: Sendable {
    /// A stable name the host uses to style or describe the phase, such as `"work"`. Never shown.
    public let kind: String
    public let title: LocalizedStringResource
    public let duration: Duration

    public init(kind: String, title: LocalizedStringResource, duration: Duration) {
        precondition(duration > .zero, "A phase needs a positive duration")
        self.kind = kind
        self.title = title
        self.duration = duration
    }
}

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
