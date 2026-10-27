import Foundation

/// The sounds a cue can make. They are generated, not recorded, so the module ships no audio
/// files and has no asset license to check.
public enum Cue: Sendable, CaseIterable {
    /// Two quick rising notes: a session started or resumed.
    case start
    /// A short beep: a new phase started.
    case phaseChange
    /// A rising three-note chime: the session is done.
    case finished

    var notes: [Tone] {
        switch self {
        case .start: [Tone(frequency: 523, duration: 0.1), Tone(frequency: 784, duration: 0.16)]
        case .phaseChange: [Tone(frequency: 880, duration: 0.18)]
        case .finished: [Tone(frequency: 660, duration: 0.16), Tone(frequency: 880, duration: 0.16),
                         Tone(frequency: 1320, duration: 0.32)]
        }
    }

    /// The cue as 16-bit mono WAV data.
    var wav: Data { Tone.wav(notes) }
}
