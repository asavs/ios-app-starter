import SwiftUI
import Theme

/// A settings row that stores one secret in a `SecureStore`: an API key, a token, a password.
///
/// The field never shows the stored value; it reports whether one exists, replaces it on Save and
/// forgets it on Clear. Accessibility identifiers for UI tests: `settings.secure.<key>.field`,
/// `.save`, `.clear` and `.status`.
public struct SecureSettingRow: View {
    @Environment(\.appTheme) private var theme
    @State private var draft = ""
    @State private var isStored = false
    @State private var failure: String?

    private let title: String
    private let key: String
    private let store: any SecureStore

    public init(_ title: String, key: String, store: any SecureStore = KeychainStore()) {
        self.title = title
        self.key = key
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(spacing: theme.spacing.small) {
                SecureField(title, text: $draft)
                    .autocorrectionDisabled() // No password content type: these are keys and tokens, not credentials AutoFill should offer to save.
                    .accessibilityIdentifier("settings.secure.\(key).field")
                Button("Save", action: save)
                    .disabled(draft.isEmpty)
                    .accessibilityIdentifier("settings.secure.\(key).save")
                if isStored {
                    Button("Clear", role: .destructive, action: clear)
                        .accessibilityIdentifier("settings.secure.\(key).clear")
                }
            }
            .buttonStyle(.borderless)
            Text(status)
                .font(theme.typography.caption)
                .foregroundStyle(failure == nil ? theme.colors.textSecondary : theme.colors.danger)
                .accessibilityIdentifier("settings.secure.\(key).status")
        }
        .onAppear(perform: refresh)
    }

    private var status: String {
        if let failure { return failure }
        return isStored ? "Stored securely on this device." : "Not set."
    }

    private func refresh() {
        do {
            isStored = try store.contains(key)
            failure = nil
        } catch {
            failure = "Could not read: \(error)"
        }
    }

    private func save() {
        do {
            try store.set(draft, for: key)
            draft = ""
            isStored = true
            failure = nil
        } catch {
            failure = "Could not save: \(error)"
        }
    }

    private func clear() {
        do {
            try store.remove(key)
            isStored = false
            failure = nil
        } catch {
            failure = "Could not clear: \(error)"
        }
    }
}
