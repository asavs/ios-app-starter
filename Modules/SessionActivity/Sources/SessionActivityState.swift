import Foundation

/// What a Live Activity shows about a session: the dynamic content state, as plain values.
///
/// The system draws the countdown itself from `phase`, so the activity needs no update while a
/// phase runs. Nothing runs when a phase ends: the app publishes the next phase the next time it
/// runs (in the foreground, or in an intent from the activity's pause button). In the meantime
/// the system re-renders the view once, at the stale date, and `shown(at:isStale:)` turns that
/// one render into the next phase from `upcoming`, the schedule the session would follow if it
/// ran on; past the schedule the view says the phase is over. `sessionEnd` is one date the system
/// counts down to without any update at all.
///
/// Everything here is encoded into the activity, within ActivityKit's 4 KB limit.
public struct SessionActivityState: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Sendable {
        case running, paused, finished
    }

    /// A phase in the schedule, with the dates it runs between if nothing pauses the session.
    public struct ScheduledPhase: Codable, Hashable, Sendable {
        /// Zero-based, like `phaseIndex`.
        public var index: Int
        public var title: String
        public var kind: String
        public var range: ClosedRange<Date>

        public init(index: Int, title: String, kind: String, range: ClosedRange<Date>) {
            self.index = index
            self.title = title
            self.kind = kind
            self.range = range
        }
    }

    /// How many phases after the current one `upcoming` carries: eight long titles fit the 4 KB
    /// limit with room to spare, and a stale render only ever needs the first.
    public static let upcomingLimit = 8

    public var status: Status
    /// Zero-based, like `SessionSnapshot.phaseIndex`.
    public var phaseIndex: Int
    public var phaseCount: Int
    /// The phase's title, resolved to the app's language.
    public var phaseTitle: String
    /// The phase's kind, such as "work" or "rest", for the view's colours.
    public var phaseKind: String
    public var phaseDuration: Duration
    /// The running phase's interval; nil while paused or finished.
    public var phase: ClosedRange<Date>?
    /// What was left of the phase when it paused; nil otherwise.
    public var pausedRemaining: Duration?
    /// When the session ends if it runs on from now; the moment it finished, once finished.
    public var sessionEnd: Date
    /// The phases after the current one, in order, each with its dates if the session runs on;
    /// at most `upcomingLimit`, and empty while paused or finished.
    public var upcoming: [ScheduledPhase]

    public init(status: Status, phaseIndex: Int, phaseCount: Int, phaseTitle: String, phaseKind: String,
                phaseDuration: Duration, phase: ClosedRange<Date>?, pausedRemaining: Duration?, sessionEnd: Date,
                upcoming: [ScheduledPhase] = []) {
        self.status = status
        self.phaseIndex = phaseIndex
        self.phaseCount = phaseCount
        self.phaseTitle = phaseTitle
        self.phaseKind = phaseKind
        self.phaseDuration = phaseDuration
        self.phase = phase
        self.pausedRemaining = pausedRemaining
        self.sessionEnd = sessionEnd
        self.upcoming = Array(upcoming.prefix(Self.upcomingLimit))
    }

    /// From 1 at the start of a paused phase to 0 at its end; 1 while running (the system draws
    /// the running fraction itself) and 0 once finished.
    public var pausedFractionRemaining: Double {
        guard let pausedRemaining, phaseDuration > .zero else { return status == .finished ? 0 : 1 }
        return pausedRemaining / phaseDuration
    }

    /// The moment after which this state is out of date: the phase's end while running, never
    /// while paused or finished.
    public var staleDate: Date? {
        status == .running ? phase?.upperBound : nil
    }

    /// The phase the schedule puts at `date` while running: the current one until it ends, then
    /// each of `upcoming` in turn; nil while paused or finished, and once the schedule is past.
    public func scheduledPhase(at date: Date) -> ScheduledPhase? {
        guard status == .running, let phase else { return nil }
        let current = ScheduledPhase(index: phaseIndex, title: phaseTitle, kind: phaseKind, range: phase)
        // Each phase starts where the one before ends, so the first whose end is still ahead is the one running.
        return ([current] + upcoming).first { date < $0.range.upperBound }
    }

    /// What the view draws at `date`. The system re-renders a stale running phase once, at its
    /// end: that render shows the next phase from the schedule, counting down to its own end as
    /// if the app had published it, or the finished session once `sessionEnd` has passed. Past the
    /// schedule's reach the state is returned unchanged and still stale, so the view says the
    /// phase is over. Anything not stale, or not running, is returned as is.
    public func shown(at date: Date, isStale: Bool) -> (state: SessionActivityState, isStale: Bool) {
        guard isStale, status == .running else { return (self, isStale) }
        if let next = scheduledPhase(at: date) {
            guard next.index != phaseIndex else { return (self, false) } // Rendered a moment early: keep counting.
            var shown = self
            shown.phaseIndex = next.index
            shown.phaseTitle = next.title
            shown.phaseKind = next.kind
            shown.phaseDuration = .seconds(next.range.upperBound.timeIntervalSince(next.range.lowerBound))
            shown.phase = next.range
            shown.upcoming = Array(upcoming.drop(while: { $0.index <= next.index }))
            return (shown, false)
        }
        if date >= sessionEnd {
            var shown = self
            shown.status = .finished
            shown.phase = nil
            shown.upcoming = []
            if let last = upcoming.last {
                shown.phaseIndex = last.index
                shown.phaseTitle = last.title
                shown.phaseKind = last.kind
            }
            return (shown, false)
        }
        return (self, true)
    }
}
