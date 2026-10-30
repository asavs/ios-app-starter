import Foundation

/// The cue settings people can change, stored in `UserDefaults` under `cues.*` keys.
///
/// `CueSettingsSection` edits them with `@AppStorage` on the same keys and defaults, and
/// `CuePlayer` reads them on every cue, so a change in Settings applies to the next sound or tap.
public struct CuePreferences: Sendable, Equatable {
    public static let soundKey = "cues.sound"
    public static let silentModeKey = "cues.playsInSilentMode"
    public static let hapticsKey = "cues.haptics"
    public static let defaultSound = true
    /// Timers usually sound with the Ring/Silent switch on silent, like the Clock app's timer.
    public static let defaultPlaysInSilentMode = true
    public static let defaultHaptics = true

    public var sound: Bool
    /// Whether sounds play when the Ring/Silent switch (or Action button) is set to silent.
    public var playsInSilentMode: Bool
    /// Whether a cue also taps. Independent of `sound`: a silent tap is a common choice.
    public var haptics: Bool

    public init(sound: Bool = defaultSound, playsInSilentMode: Bool = defaultPlaysInSilentMode,
                haptics: Bool = defaultHaptics) {
        self.sound = sound
        self.playsInSilentMode = playsInSilentMode
        self.haptics = haptics
    }

    /// The stored values, or the defaults for keys never written.
    public init(defaults: UserDefaults) {
        self.init(sound: defaults.object(forKey: Self.soundKey) as? Bool ?? Self.defaultSound,
                  playsInSilentMode: defaults.object(forKey: Self.silentModeKey) as? Bool ?? Self.defaultPlaysInSilentMode,
                  haptics: defaults.object(forKey: Self.hapticsKey) as? Bool ?? Self.defaultHaptics)
    }
}
