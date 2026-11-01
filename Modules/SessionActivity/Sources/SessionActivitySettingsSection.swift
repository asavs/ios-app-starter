import SwiftUI

/// The Live Activity setting as a form section, for the Settings module's builder or any form.
/// This module doesn't depend on Settings; the app places the section. Accessibility identifier:
/// `sessionActivity.enabled`.
public struct SessionActivitySettingsSection: View {
    @AppStorage private var isEnabled: Bool

    /// Pass the defaults `SessionActivityController` reads, if not `.standard`.
    public init(defaults: UserDefaults = .standard) {
        _isEnabled = AppStorage(wrappedValue: SessionActivityPreferences.defaultEnabled,
                                SessionActivityPreferences.enabledKey, store: defaults)
    }

    public var body: some View {
        Section {
            Toggle(isOn: $isEnabled) { Text("Live Activity", bundle: .module) }
                .accessibilityIdentifier("sessionActivity.enabled")
        } footer: {
            Text("Shows the running session on the Lock Screen and in the Dynamic Island, where it keeps counting down with the app closed. Turning it off removes the current one.",
                 bundle: .module)
        }
    }
}
