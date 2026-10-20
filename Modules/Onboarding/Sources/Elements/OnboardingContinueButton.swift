import SwiftUI
import Theme

/// The flow's single call to action: Liquid Glass on iOS 26 and later, the theme's primary style
/// before that. While `isBusy` (a permission request in flight) it shows a spinner and ignores taps.
struct OnboardingContinueButton: View {
    let title: String
    let isBusy: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .modifier(ProminentButton())
        .disabled(isBusy)
        .accessibilityIdentifier("onboarding.next")
        .accessibilityLabel(title)
    }
}

private struct ProminentButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            content
                .buttonStyle(.primary)
        }
    }
}

#Preview("Continue") {
    VStack {
        OnboardingContinueButton(title: "Continue", isBusy: false) {}
        OnboardingContinueButton(title: "Continue", isBusy: true) {}
    }
    .padding()
}
