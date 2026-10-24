import SwiftUI
import Theme

/// The flow's single call to action in the theme's prominent style (Liquid Glass on iOS 26 and later).
/// While `isBusy` (a permission request in flight) it shows a spinner and ignores taps.
struct OnboardingContinueButton: View {
    let title: LocalizedStringResource
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
        .prominentButtonStyle()
        .disabled(isBusy)
        .accessibilityIdentifier("onboarding.next")
        .accessibilityLabel(Text(title))
        .accessibilityValue(isBusy ? Text("Waiting", bundle: .module) : Text(verbatim: "")) // Otherwise VoiceOver says only "dimmed" mid-request.
    }
}

#Preview("Continue") {
    VStack {
        OnboardingContinueButton(title: "Continue", isBusy: false) {}
        OnboardingContinueButton(title: "Continue", isBusy: true) {}
    }
    .padding()
}
