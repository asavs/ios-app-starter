import Foundation
import SessionTimer

public extension SessionActivityState {
    /// The activity content for a session at `now`, or nil for a session that hasn't started: a
    /// ready session shows no activity.
    init?(_ snapshot: SessionSnapshot, plan: SessionPlan, now: Date) {
        let phase = plan.phases[snapshot.phaseIndex]
        let title = String(localized: phase.title)
        switch snapshot.status {
        case .ready:
            return nil
        case .running:
            self.init(status: .running, phaseIndex: snapshot.phaseIndex, phaseCount: plan.phases.count,
                      phaseTitle: title, phaseKind: phase.kind, phaseDuration: snapshot.phaseDuration,
                      phase: now.adding(.zero - snapshot.phaseElapsed)...now.adding(snapshot.phaseRemaining),
                      pausedRemaining: nil, sessionEnd: now.adding(snapshot.remaining))
        case .paused:
            self.init(status: .paused, phaseIndex: snapshot.phaseIndex, phaseCount: plan.phases.count,
                      phaseTitle: title, phaseKind: phase.kind, phaseDuration: snapshot.phaseDuration, phase: nil,
                      pausedRemaining: snapshot.phaseRemaining, sessionEnd: now.adding(snapshot.remaining))
        case .finished:
            self.init(status: .finished, phaseIndex: snapshot.phaseIndex, phaseCount: plan.phases.count,
                      phaseTitle: title, phaseKind: phase.kind, phaseDuration: snapshot.phaseDuration,
                      phase: nil, pausedRemaining: nil, sessionEnd: now)
        }
    }
}

private extension SessionSnapshot {
    var phaseElapsed: Duration { phaseDuration - phaseRemaining }
}

private extension Date {
    func adding(_ duration: Duration) -> Date {
        addingTimeInterval(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
    }
}
