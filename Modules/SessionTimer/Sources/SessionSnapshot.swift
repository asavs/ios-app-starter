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
