import AVFoundation

/// Plays cues while the app is in the foreground, following `CuePreferences`.
///
/// Sounds mix with music and podcasts and never lower them. With `playsInSilentMode` on they use
/// the playback audio category, which sounds through the Ring/Silent switch; off, they use the
/// ambient category, which the switch silences. Nothing here keeps the app running in the
/// background: a suspended app plays nothing (see docs/research/background-audio.md).
@MainActor
public final class CuePlayer {
    private let defaults: UserDefaults
    private let output: (Cue, CuePreferences) -> Void

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let speaker = CueSpeaker()
        output = { speaker.play($0, playsInSilentMode: $1.playsInSilentMode) }
    }

    /// For tests: records what would play instead of playing it.
    init(defaults: UserDefaults, output: @escaping (Cue, CuePreferences) -> Void) {
        self.defaults = defaults
        self.output = output
    }

    public func play(_ cue: Cue) {
        let preferences = CuePreferences(defaults: defaults)
        guard preferences.sound else { return }
        output(cue, preferences)
    }
}
