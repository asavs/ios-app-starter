import Foundation

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
    /// Started since the last reset, so a pause at zero elapsed time still reads as paused.
    private var hasStarted = false

    public init(plan: SessionPlan) {
        self.plan = plan
    }

    /// Restore a stored position. `now` and `date` are the same moment on the two clocks; a run
    /// stored as started in the future (a clock change) counts as started now.
    public init(plan: SessionPlan, state: SessionClockState, at now: Instant, date: Date) {
        self.plan = plan
        banked = min(max(.zero, state.banked), plan.totalDuration)
        hasStarted = state.hasStarted || state.runningSince != nil
        runningSince = state.runningSince.map { since in
            now - .seconds(max(0, date.timeIntervalSince(since)))
        }
    }

    /// The position as dates, to store. `now` and `date` are the same moment on the two clocks.
    public func state(at now: Instant, date: Date) -> SessionClockState {
        SessionClockState(banked: banked,
                          runningSince: runningSince.map { date.addingTimeInterval(-(now - $0).seconds) },
                          hasStarted: hasStarted)
    }

    /// Start, or resume after a pause. Does nothing while running or once finished.
    public mutating func start(at now: Instant) {
        guard runningSince == nil, banked < plan.totalDuration else { return }
        runningSince = now
        hasStarted = true
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
        hasStarted = false
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
        let status: SessionSnapshot.Status = runningSince != nil ? .running
            : (hasStarted || elapsed > .zero ? .paused : .ready)
        return SessionSnapshot(status: status, phaseIndex: index, phaseDuration: duration,
                               phaseRemaining: duration - (elapsed - phaseStart),
                               elapsed: elapsed, remaining: total - elapsed)
    }

    private func elapsed(at now: Instant) -> Duration {
        let running = runningSince.map { max(.zero, now - $0) } ?? .zero
        return min(plan.totalDuration, banked + running)
    }
}
