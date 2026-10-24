import SwiftUI
import Theme

/// A settings row that stores one secret in a `SecureStore`: an API key, a token, a password.
///
/// The field never shows the stored value; it reports whether one exists, replaces it on Save and
/// forgets it on Clear. Accessibility identifiers for UI tests: `settings.secure.<key>.field`,
/// `.save`, `.clear` and `.status`.
public struct SecureSettingRow: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft = ""
    /// Whether the store holds a value; `nil` until the first read returns.
    @State private var isStored: Bool?
    /// A save or clear in flight; the buttons wait for it.
    @State private var isWorking = false
    @State private var failure: String?

    private let title: LocalizedStringResource
    private let key: String
    private let store: any SecureStore

    /// - Parameter title: The field's placeholder, looked up in the app's string catalog when a literal.
    public init(_ title: LocalizedStringResource, key: String, store: any SecureStore = KeychainStore()) {
        self.title = title
        self.key = key
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            // At accessibility text sizes the buttons move under the field instead of squeezing it.
            let entry = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: theme.spacing.small))
                : AnyLayout(HStackLayout(spacing: theme.spacing.small))
            entry {
                SecureField(text: $draft) { Text(title) }
                    .autocorrectionDisabled() // No password content type: these are keys and tokens, not credentials AutoFill should offer to save.
                    .accessibilityIdentifier("settings.secure.\(key).field")
                HStack(spacing: theme.spacing.medium) {
                    Button(action: save) { Text("Save", bundle: .module) }
                        .disabled(draft.isEmpty || isWorking)
                        .accessibilityIdentifier("settings.secure.\(key).save")
                    if isStored == true {
                        Button(role: .destructive, action: clear) { Text("Clear", bundle: .module) }
                            .disabled(isWorking)
                            .accessibilityIdentifier("settings.secure.\(key).clear")
                    }
                }
            }
            .buttonStyle(.borderless)
            Text(status)
                .font(theme.typography.caption)
                .foregroundStyle(failure == nil ? theme.colors.textSecondary : theme.colors.danger)
                .accessibilityIdentifier("settings.secure.\(key).status")
        }
        .task { await refresh() }
    }

    private var status: String {
        if let failure { return failure }
        switch isStored {
        case true?: return String(localized: "Stored securely on this device.", bundle: .module)
        case false?: return String(localized: "Not set.", bundle: .module)
        case nil: return String(localized: "Checking…", bundle: .module)
        }
    }

    // Keychain calls block their thread, so every one goes through `perform`, off the main actor.

    private func refresh() async {
        let key = key
        do {
            isStored = try await store.perform { try $0.contains(key) }
            failure = nil
        } catch {
            failure = String(localized: "Could not read: \(String(describing: error))", bundle: .module)
        }
    }

    private func save() {
        let (key, value) = (key, draft)
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.perform { try $0.set(value, for: key) }
                draft = ""
                isStored = true
                failure = nil
                announce(String(localized: "\(String(localized: title)) saved.", bundle: .module))
            } catch {
                failure = String(localized: "Could not save: \(String(describing: error))", bundle: .module)
                announce(failure)
            }
        }
    }

    private func clear() {
        let key = key
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await store.perform { try $0.remove(key) }
                isStored = false
                failure = nil
                announce(String(localized: "\(String(localized: title)) cleared.", bundle: .module))
            } catch {
                failure = String(localized: "Could not clear: \(String(describing: error))", bundle: .module)
                announce(failure)
            }
        }
    }

    /// The field empties and the status changes without moving focus, so VoiceOver says what happened.
    private func announce(_ message: String?) {
        guard let message else { return }
        AccessibilityNotification.Announcement(message).post()
    }
}
