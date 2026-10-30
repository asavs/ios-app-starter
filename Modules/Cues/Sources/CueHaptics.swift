import SwiftUI

extension Cue {
    /// The system haptic that goes with the cue, for `sensoryFeedback`. A session starting is
    /// `.start`, a new phase an `.impact`, and the end `.success`: the HIG's semantic feedback
    /// types, so the taps match what the system plays for the same moments elsewhere.
    public var haptic: SensoryFeedback {
        switch self {
        case .start: .start
        case .phaseChange: .impact
        case .finished: .success
        }
    }
}

extension CuePlayer {
    /// The haptic for a cue, or nil when haptics are off in `CuePreferences`. Return it from a
    /// `sensoryFeedback(trigger:_:)` closure:
    ///
    /// ```swift
    /// .sensoryFeedback(trigger: snapshot) { old, new in
    ///     cue(from: old, to: new).flatMap(player.haptic(for:))
    /// }
    /// ```
    ///
    /// Playing a haptic is the view's job (SwiftUI owns the generator); the player only decides.
    public func haptic(for cue: Cue) -> SensoryFeedback? {
        CuePreferences(defaults: defaults).haptics ? cue.haptic : nil
    }
}
