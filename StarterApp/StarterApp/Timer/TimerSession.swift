import Foundation
import Observation
import SwiftUI
import UIKit
#if canImport(SessionTimer)
import SessionTimer
#if canImport(Cues)
import Cues
#endif
#if canImport(SessionActivity)
import SessionActivity
#endif

/// The app's one timer session, owned above any screen: which plan is chosen, its stored times,
/// the primary button, which cue each change of the session plays, and the session's record and
/// Live Activity. The Timer screen reads it from the environment and sends commands; hiding,
/// reordering or rebuilding that screen changes nothing here, and a session keeps its record, its
/// cues and its activity current while no screen shows it, because the timer reports every change
/// to this owner directly (`SessionTimer.onChange`), not through a view.
///
/// `shared` is the app's instance, created at launch after the Live Activity service; tests make
/// their own with an isolated defaults suite, a controlled clock and a recording activity host.
@MainActor @Observable
final class TimerSession {
    let timer: SessionTimer

    /// Choosing a plan loads its stored times and starts over.
    var plan: TimerPlan {
        didSet {
            let stored = Self.storedTimes(for: plan, in: defaults)
            // Assigning different times loads them (see `times`); equal times need loading here.
            if stored == times { load() } else { times = stored }
        }
    }

    /// The chosen plan's times. Editing them stores them and starts over.
    var times: PlanTimes {
        didSet {
            guard times != oldValue else { return }
            defaults.set(times.rawValue, forKey: plan.storageKey)
            load()
        }
    }

    /// Identifies one run of the session, from its start from the beginning until the next such
    /// start: the stored record and the Live Activity carry it.
    private(set) var sessionID = UUID()

    private let defaults: UserDefaults
#if canImport(Cues)
    /// Plays a cue; tests replace it to record what would play.
    @ObservationIgnored var play: (Cue) -> Void
    /// The haptic for a cue, or nil with haptics off in Settings.
    @ObservationIgnored var haptic: (Cue) -> SensoryFeedback?
#endif
#if canImport(SessionActivity)
    /// The app's Live Activity, or nil in tests.
    @ObservationIgnored private var activity: StarterSessionActivity?
#endif

    init(defaults: UserDefaults = .standard, plan: TimerPlan = .intervals,
         now: @escaping () -> ContinuousClock.Instant = { .now }) {
        self.defaults = defaults
        self.plan = plan
        let times = Self.storedTimes(for: plan, in: defaults)
        self.times = times
        timer = SessionTimer(plan: plan.session(times), now: now)
#if canImport(Cues)
        let player = CuePlayer(defaults: defaults)
        play = player.play
        haptic = player.haptic
#endif
        adoptStoredSession()
        timer.onChange = { [weak self] old, new in self?.sessionChanged(from: old, to: new) }
    }

    /// The app's session. Created once, at launch, so a stored session is adopted and its activity
    /// reconciled before any tab shows, whichever tab that is.
#if canImport(SessionActivity)
    static let shared = TimerSession(defaults: StarterDefaults.store, activity: .shared)
#else
    static let shared = TimerSession(defaults: StarterDefaults.store)
#endif

    /// Follow the stored record whenever the app returns to the foreground: the activity's button
    /// may have paused or resumed the session while the app was away. The owner listens, not a
    /// screen, so it works with the Timer tab hidden or never shown. Call once, for `shared`.
    func observeForeground() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restoreFromRecord() }
        }
    }

#if canImport(SessionActivity)
    /// The Timer tab's model: the session also drives the app's Live Activity.
    convenience init(defaults: UserDefaults = .standard, activity: StarterSessionActivity,
                     now: @escaping () -> ContinuousClock.Instant = { .now }) {
        self.init(defaults: defaults, now: now)
        self.activity = activity
        // The activity's button changes the stored record in this process: follow it on the screen.
        activity.recordChanged = { [weak self] in self?.restoreFromRecord() }
    }
#endif

    /// A session underway when the app last ran (killed in the background, or opened from its
    /// activity) continues on this screen under its own identifier. Without this the screen showed
    /// a fresh session beside the activity the launch had just brought up to date, and a tap on
    /// Start made a second session and left the first's activity to the system's limit.
    private func adoptStoredSession() {
        guard let record = SessionRecord.load(from: defaults), let times = PlanTimes(rawValue: record.times),
              let session = record.sessionPlan else { return }
        plan = record.plan
        self.times = times
        sessionID = record.id
        timer.load(session, state: record.clock)
    }

    /// Replace the timer's plan; the next start is a new session.
    private func load() {
        timer.load(plan.session(times))
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
        case .paused: timer.start()
        case .finished:
            timer.reset()
            startSession()
        case .ready: startSession()
        }
    }

    func skip() { timer.skipToNextPhase() }

    func reset() { timer.reset() }

    /// A start from the beginning is a new session, with its own record and activity. The identifier
    /// changes here and not on reset, so the reset still reaches the old session's activity.
    private func startSession() {
        sessionID = UUID()
        timer.start()
    }

    /// Called by the timer with each pair of snapshots: plays the cue for a start, a new phase or
    /// the end, keeps the stored record current, and passes the change on to the Live Activity.
    /// Ticks within a phase change nothing but the remaining time, which the record and the
    /// activity derive. A load (adopting a record, a new plan) also arrives here: a plan change
    /// returns the session to ready, which clears the record of the one before.
    private func sessionChanged(from old: SessionSnapshot, to new: SessionSnapshot) {
        guard !isRestoring else { return }
#if canImport(Cues)
        if let cue = Self.cue(for: new.transition(from: old)) { play(cue) }
#endif
        guard new.status != old.status || new.phaseIndex != old.phaseIndex else { return }
        if new.status == .ready {
            SessionRecord.clear(in: defaults)
        } else {
            SessionRecord(id: sessionID, plan: plan, times: times, clock: timer.state()).save(to: defaults)
        }
#if canImport(SessionActivity)
        activity?.controller.sessionChanged(new, plan: timer.plan,
                                            attributes: StarterSessionActivity.attributes(for: plan, sessionID: sessionID))
#endif
    }

    /// The app is back in the foreground: if the Live Activity's button paused or resumed this
    /// session meanwhile, take the stored position over. The intent already saved the record and
    /// published the change, so this load is silent: no second save, publication or cue.
    func restoreFromRecord() {
        guard let record = SessionRecord.load(from: defaults), record.id == sessionID,
              record.clock.isRunning != (timer.snapshot.status == .running) else { return }
        isRestoring = true
        defer { isRestoring = false }
        timer.load(plan.session(times), state: record.clock)
    }

    /// While a stored position is being loaded: the change came from the record, not from here.
    @ObservationIgnored private var isRestoring = false

    /// The haptic for the change between two snapshots, for the view's `sensoryFeedback`. Nil
    /// for pauses, resets and plan changes, and for everything with haptics off.
    func haptic(from old: SessionSnapshot, to new: SessionSnapshot) -> SensoryFeedback? {
#if canImport(Cues)
        Self.cue(for: new.transition(from: old)).flatMap(haptic)
#else
        switch new.transition(from: old) {
        case .started, .resumed: .start
        case .phaseStarted: .impact
        case .finished: .success
        case nil: nil
        }
#endif
    }

#if canImport(Cues)
    /// A start or resume, a new phase and the end each have a cue; nothing else does.
    static func cue(for transition: SessionTransition?) -> Cue? {
        switch transition {
        case .started, .resumed: .start
        case .phaseStarted: .phaseChange
        case .finished: .finished
        case nil: nil
        }
    }
#endif

    private static func storedTimes(for plan: TimerPlan, in defaults: UserDefaults) -> PlanTimes {
        defaults.string(forKey: plan.storageKey).flatMap(PlanTimes.init(rawValue:)) ?? plan.defaultTimes
    }
}
#endif
