import Foundation

/// What a Live Activity shows about a session: the dynamic content state, as plain values.
///
/// The system draws the countdown itself from `phase`, so the activity needs no update while a
/// phase runs. Nothing runs when a phase ends: the app publishes the next phase the next time it
/// runs (in the foreground, or in an intent from the activity's pause button), and the view uses
/// the stale date to say the phase is over in the meantime. `sessionEnd` is one date the system
/// counts down to without any update at all.
///
/// Everything here is encoded into the activity, within ActivityKit's 4 KB limit.
public struct SessionActivityState: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Sendable {
        case running, paused, finished
    }

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

    public init(status: Status, phaseIndex: Int, phaseCount: Int, phaseTitle: String, phaseKind: String,
                phaseDuration: Duration, phase: ClosedRange<Date>?, pausedRemaining: Duration?, sessionEnd: Date) {
        self.status = status
        self.phaseIndex = phaseIndex
        self.phaseCount = phaseCount
        self.phaseTitle = phaseTitle
        self.phaseKind = phaseKind
        self.phaseDuration = phaseDuration
        self.phase = phase
        self.pausedRemaining = pausedRemaining
        self.sessionEnd = sessionEnd
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
}
