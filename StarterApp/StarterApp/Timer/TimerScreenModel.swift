import Foundation
import Observation
#if canImport(SessionTimer)
import SessionTimer
#if canImport(Cues)
import Cues
#endif

/// What the Timer tab does, apart from drawing it: which plan is chosen, its stored times, the
/// primary button, and which cue each change of the session plays. The view only lays it out.
@MainActor @Observable
final class TimerScreenModel {
    let timer: SessionTimer

    /// Choosing a plan loads its stored times and starts over.
    var plan: TimerPlan {
        didSet {
            let stored = Self.storedTimes(for: plan, in: defaults)
            // Assigning different times loads them (see `times`); equal times need loading here.
            if stored == times { timer.load(plan.session(times)) } else { times = stored }
        }
    }

    /// The chosen plan's times. Editing them stores them and starts over.
    var times: PlanTimes {
        didSet {
            guard times != oldValue else { return }
            defaults.set(times.rawValue, forKey: plan.storageKey)
            timer.load(plan.session(times))
        }
    }

    private let defaults: UserDefaults
#if canImport(Cues)
    /// Plays a cue; tests replace it to record what would play.
    @ObservationIgnored var play: (Cue) -> Void
#endif

    init(defaults: UserDefaults = .standard, plan: TimerPlan = .intervals,
         now: @escaping () -> ContinuousClock.Instant = { .now }) {
        self.defaults = defaults
        self.plan = plan
        let times = Self.storedTimes(for: plan, in: defaults)
        self.times = times
        timer = SessionTimer(plan: plan.session(times), now: now)
#if canImport(Cues)
        play = CuePlayer(defaults: defaults).play
#endif
    }

    /// Changing the plan or its times starts over, so both wait until a session isn't underway.
    var canChangePlan: Bool { timer.snapshot.status == .ready || timer.snapshot.status == .finished }

    var isRunning: Bool { timer.snapshot.status == .running }

    var primaryTitle: LocalizedStringResource {
        switch timer.snapshot.status {
        case .ready: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .finished: "Start again"
        }
    }

    func primaryAction() {
        switch timer.snapshot.status {
        case .running: timer.pause()
        case .finished:
            timer.reset()
            timer.start()
        case .ready, .paused: timer.start()
        }
    }

    func skip() { timer.skipToNextPhase() }

    func reset() { timer.reset() }

    /// Called with each pair of snapshots; plays the cue for a start, a new phase or the end.
    func sessionChanged(from old: SessionSnapshot, to new: SessionSnapshot) {
#if canImport(Cues)
        switch new.transition(from: old) {
        case .started, .resumed: play(.start)
        case .phaseStarted: play(.phaseChange)
        case .finished: play(.finished)
        case nil: break
        }
#endif
    }

    private static func storedTimes(for plan: TimerPlan, in defaults: UserDefaults) -> PlanTimes {
        defaults.string(forKey: plan.storageKey).flatMap(PlanTimes.init(rawValue:)) ?? plan.defaultTimes
    }
}
#endif
