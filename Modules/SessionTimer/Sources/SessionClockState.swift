import Foundation

/// A clock's position as wall-clock values, for storing across launches.
///
/// `SessionClock` anchors a running session on a `ContinuousClock` instant, which means nothing
/// outside the process that read it. Convert with `SessionClock.state(at:date:)` when saving and
/// `SessionClock(plan:state:at:date:)` when restoring, for example in an App Intent the system
/// performs in a freshly launched app, or when the Timer screen returns to the foreground.
public struct SessionClockState: Codable, Hashable, Sendable {
    /// Time run before the current run, excluding pauses.
    public var banked: Duration
    /// When the current run started, or nil while paused, ready or finished.
    public var runningSince: Date?
    /// Started since the last reset, so a pause at zero elapsed time still reads as paused.
    public var hasStarted: Bool

    public init(banked: Duration, runningSince: Date?, hasStarted: Bool) {
        self.banked = banked
        self.runningSince = runningSince
        self.hasStarted = hasStarted
    }

    public var isRunning: Bool { runningSince != nil }
}
