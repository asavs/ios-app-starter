import Foundation

/// Something worth a cue between two snapshots. Pausing, skipping while paused, resetting and
/// loading a plan are not transitions.
public enum SessionTransition: Sendable, Equatable {
    /// Began running from the start (or again after finishing).
    case started
    /// Ran again after a pause.
    case resumed
    /// A new phase began while running.
    case phaseStarted(index: Int)
    case finished
}

public extension SessionSnapshot {
    /// The transition from `previous` to this snapshot, if any. Call it from `onChange` with the
    /// old and new snapshot to play a sound or haptic once per change.
    func transition(from previous: SessionSnapshot) -> SessionTransition? {
        switch (previous.status, status) {
        case (.finished, .finished): return nil
        case (_, .finished): return .finished
        case (.ready, .running), (.finished, .running): return .started
        case (.paused, .running): return .resumed
        case (.running, .running) where phaseIndex != previous.phaseIndex: return .phaseStarted(index: phaseIndex)
        default: return nil
        }
    }
}
