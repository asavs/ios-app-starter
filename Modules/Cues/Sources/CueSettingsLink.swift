import SwiftUI

/// The cue settings as a row that pushes its own screen, for apps whose Settings nests like iOS
/// Settings does. The same three toggles as `CueSettingsSection`, one level down.
///
/// ```swift
/// SettingsView {
///     Section { CueSettingsLink() }
/// }
/// ```
///
/// Accessibility identifier: `settings.cues`. This module doesn't depend on Settings, so the row is
/// a plain `NavigationLink` shaped like the Settings module's `SettingsLink`.
public struct CueSettingsLink: View {
    private let defaults: UserDefaults

    /// Pass the defaults `CuePlayer` reads, if not `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var body: some View {
        NavigationLink {
            Form { CueSettingsSection(defaults: defaults) }
                .navigationTitle(Text("Sounds & Haptics", bundle: .module))
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            Label { Text("Sounds & Haptics", bundle: .module) } icon: { Image(systemName: "speaker.wave.2") }
        }
        .accessibilityIdentifier("settings.cues")
    }
}
