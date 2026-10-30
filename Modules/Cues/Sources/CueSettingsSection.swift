import SwiftUI

/// The cue settings as a form section. Put it in the Settings module's builder, or any form:
///
/// ```swift
/// SettingsView {
///     CueSettingsSection()
/// }
/// ```
///
/// This module doesn't depend on Settings; the app places the section. Accessibility
/// identifiers: `cues.sound`, `cues.silentMode`, `cues.haptics`.
public struct CueSettingsSection: View {
    @AppStorage private var sound: Bool
    @AppStorage private var playsInSilentMode: Bool
    @AppStorage private var haptics: Bool

    /// Pass the defaults `CuePlayer` reads, if not `.standard`.
    public init(defaults: UserDefaults = .standard) {
        _sound = AppStorage(wrappedValue: CuePreferences.defaultSound, CuePreferences.soundKey, store: defaults)
        _playsInSilentMode = AppStorage(wrappedValue: CuePreferences.defaultPlaysInSilentMode,
                                        CuePreferences.silentModeKey, store: defaults)
        _haptics = AppStorage(wrappedValue: CuePreferences.defaultHaptics, CuePreferences.hapticsKey, store: defaults)
    }

    public var body: some View {
        Section {
            Toggle(isOn: $sound) { Text("Sounds", bundle: .module) }
                .accessibilityIdentifier("cues.sound")
            Toggle(isOn: $playsInSilentMode) { Text("Play in silent mode", bundle: .module) }
                .disabled(!sound)
                .accessibilityIdentifier("cues.silentMode")
            Toggle(isOn: $haptics) { Text("Haptics", bundle: .module) }
                .accessibilityIdentifier("cues.haptics")
        } header: {
            Text("Sounds & Haptics", bundle: .module)
        } footer: {
            Text("A tone when a session starts, a beep at each new phase and a chime when the session ends, mixed with any music or podcast. Haptics tap at the same moments. Both work only while the app is open.",
                 bundle: .module)
        }
    }
}
