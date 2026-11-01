import SwiftUI
import Theme

/// What people see when the store won't open: the reason, Retry, and Start Over behind a
/// confirmation, since starting over erases what the files hold. Accessibility identifiers:
/// `database.retry`, `database.startOver`, `database.startOver.confirm`.
public struct DatabaseRecoveryView: View {
    private let loader: DatabaseLoader
    private let error: DatabaseOpenError
    @State private var isConfirmingStartOver = false
    @State private var startOverFailure: String?
    @State private var isShowingStartOverFailure = false
    @Environment(\.appTheme) private var theme

    public init(loader: DatabaseLoader, error: DatabaseOpenError) {
        self.loader = loader
        self.error = error
    }

    public var body: some View {
        VStack(spacing: theme.spacing.large) {
            EmptyStateView(systemImage: "externaldrive.badge.exclamationmark",
                           title: LocalizedStringResource("Your data couldn't be opened", bundle: .module),
                           message: LocalizedStringResource("Nothing has been changed. Try again, or start over with an empty store.", bundle: .module),
                           actionTitle: LocalizedStringResource("Try Again", bundle: .module),
                           action: loader.retry)
                .accessibilityIdentifier("database.retry")
            Text(verbatim: error.description)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button(role: .destructive, action: confirmStartOver) {
                Text("Start Over", bundle: .module)
            }
            .accessibilityIdentifier("database.startOver")
            .confirmationDialog(Text("Start over with an empty store?", bundle: .module),
                                isPresented: $isConfirmingStartOver, titleVisibility: .visible) {
                Button(role: .destructive, action: startOver) { Text("Erase and Start Over", bundle: .module) }
                    .accessibilityIdentifier("database.startOver.confirm")
            } message: {
                Text("The data in the current store is deleted. It can't be undone.", bundle: .module)
            }
            .alert(Text("Couldn't start over", bundle: .module), isPresented: $isShowingStartOverFailure) {
            } message: {
                Text(verbatim: startOverFailure ?? "")
            }
        }
        .padding()
        .background(theme.colors.background)
    }

    private func confirmStartOver() {
        isConfirmingStartOver = true
    }

    private func startOver() {
        do {
            try loader.startOver()
        } catch {
            startOverFailure = error.localizedDescription
            isShowingStartOverFailure = true
        }
    }
}
