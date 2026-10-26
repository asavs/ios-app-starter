import SwiftUI

/// A reset that takes effect after relaunch confirms its result and becomes inactive.
struct NextLaunchResetButton: View {
    let title: LocalizedStringResource
    let done: LocalizedStringResource
    @Binding var isDone: Bool
    let action: () -> Void

    init(_ title: LocalizedStringResource, done: LocalizedStringResource, isDone: Binding<Bool>,
         action: @escaping () -> Void) {
        self.title = title
        self.done = done
        _isDone = isDone
        self.action = action
    }

    var body: some View {
        Button(action: reset) {
            if isDone {
                Label { Text(done) } icon: { Image(systemName: "checkmark") }
            } else {
                Text(title)
            }
        }
        .disabled(isDone)
    }

    private func reset() {
        action()
        isDone = true
        AccessibilityNotification.Announcement(String(localized: done)).post()
    }
}
