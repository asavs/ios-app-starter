import SwiftUI

/// A destructive form row that erases a `LocalDataReset` after a confirmation dialog: the HIG's
/// pattern for an uncommon action that can't be undone, with a button named for what it does and the
/// dialog's own Cancel. Put it in a section of its own at the end of `SettingsView`'s `extra` rows.
///
/// Accessibility identifiers: `settings.reset` (the row) and `settings.reset.confirm` (the dialog's
/// Erase button).
public struct ResetLocalDataButton: View {
    private let reset: LocalDataReset
    private let onErased: () -> Void
    @State private var isConfirming = false
    @State private var failure: String?
    @State private var isShowingFailure = false

    /// - Parameter onErased: Runs after everything was erased, for the app to refresh what it
    ///   caches outside the stores.
    public init(reset: LocalDataReset, onErased: @escaping () -> Void = {}) {
        self.reset = reset
        self.onErased = onErased
    }

    public var body: some View {
        Button(role: .destructive, action: confirm) {
            Text("Erase Local Data", bundle: .module)
        }
        .accessibilityIdentifier("settings.reset")
        .confirmationDialog(Text("Erase all local data?", bundle: .module), isPresented: $isConfirming, titleVisibility: .visible) {
            Button(role: .destructive, action: erase) { Text("Erase", bundle: .module) }
                .accessibilityIdentifier("settings.reset.confirm")
        } message: {
            Text("This removes everything the app stored on this device, including your settings and saved secrets. It can't be undone.",
                 bundle: .module)
        }
        .alert(Text("Couldn't erase everything", bundle: .module), isPresented: $isShowingFailure) {
        } message: {
            Text(verbatim: failure ?? "")
        }
    }

    private func confirm() {
        isConfirming = true
    }

    private func erase() {
        do {
            try reset.erase()
            onErased()
        } catch {
            failure = String(describing: error)
            isShowingFailure = true
        }
    }
}
