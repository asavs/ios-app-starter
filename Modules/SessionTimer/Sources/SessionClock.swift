import Foundation

/// Where a session is at one instant.
public struct SessionSnapshot: Sendable, Equatable {
    public enum Status: Sendable, Equatable {
        case ready, running, paused, finished
    }

    public let status: Status
    /// The current phase, or the last one once the session has finished.
    public let phaseIndex: Int
    public let phaseDuration: Duration
    public let phaseRemaining: Duration
    /// Time run so far, excluding pauses.
    public let elapsed: Duration
    public let remaining: Duration

    /// From 1 at the start of the phase to 0 at its end, for a progress ring.
    public var phaseFractionRemaining: Double { phaseRemaining.seconds / phaseDuration.seconds }
}

/// A session's state as a value: it stores when it last started and how long it had run before
/// that, and derives everything else from the instant it is asked about. Time is never added up
/// tick by tick, so it cannot drift, and `ContinuousClock` keeps counting while the phone sleeps.
///
/// Pass `ContinuousClock.now` in the app and fixed instants in tests. `SessionTimer` drives one for
/// SwiftUI.
public struct SessionClock: Sendable {
    public typealias Instant = ContinuousClock.Instant

    public let plan: SessionPlan
    private var banked: Duration = .zero
    private var runningSince: Instant?

    public init(plan: SessionPlan) {
        self.plan = plan
    }

    /// Start, or resume after a pause. Does nothing while running or once finished.
    public mutating func start(at now: Instant) {
        guard runningSince == nil, banked < plan.totalDuration else { return }
        runningSince = now
    }

    public mutating func pause(at now: Instant) {
        guard runningSince != nil else { return }
        banked = elapsed(at: now)
        runningSince = nil
    }

    /// Jump to the start of the next phase; from the last phase, finish. Keeps running or paused.
    public mutating func skipToNextPhase(at now: Instant) {
        let current = snapshot(at: now)
        guard current.status != .finished else { return }
        let next = current.phaseIndex + 1
        banked = next < plan.phases.count ? plan.start(ofPhase: next) : plan.totalDuration
        if runningSince != nil { runningSince = now }
    }

    /// Back to the start, ready to run again.
    public mutating func reset() {
        banked = .zero
        runningSince = nil
    }

    public func snapshot(at now: Instant) -> SessionSnapshot {
        let elapsed = elapsed(at: now)
        let total = plan.totalDuration
        guard elapsed < total else {
            let last = plan.phases.count - 1
            return SessionSnapshot(status: .finished, phaseIndex: last, phaseDuration: plan.phases[last].duration,
                                   phaseRemaining: .zero, elapsed: total, remaining: .zero)
        }
        // A phase owns its start instant, not its end, so a boundary belongs to the next phase.
        var phaseStart = Duration.zero
        var index = 0
        while phaseStart + plan.phases[index].duration <= elapsed {
            phaseStart += plan.phases[index].duration
            index += 1
        }
        let duration = plan.phases[index].duration
        let status: SessionSnapshot.Status = runningSince != nil ? .running : (elapsed > .zero ? .paused : .ready)
        return SessionSnapshot(status: status, phaseIndex: index, phaseDuration: duration,
                               phaseRemaining: duration - (elapsed - phaseStart),
                               elapsed: elapsed, remaining: total - elapsed)
    }

    private func elapsed(at now: Instant) -> Duration {
        let running = runningSince.map { max(.zero, now - $0) } ?? .zero
        return min(plan.totalDuration, banked + running)
    }
}

extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
