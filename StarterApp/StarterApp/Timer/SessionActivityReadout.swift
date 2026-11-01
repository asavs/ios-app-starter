import SwiftUI
#if canImport(SessionTimer) && canImport(SessionActivity)
import SessionTimer

/// For UI tests only: how many Live Activities the app has, as a label they can read, since a test
/// can't see the Dynamic Island of another process. Shown with the `-sessionActivity.readout`
/// launch argument; redrawn with each snapshot so the count follows the session.
struct SessionActivityReadout: View {
    let snapshot: SessionSnapshot

    static let isRequested = ProcessInfo.processInfo.arguments.contains("-sessionActivity.readout")

    var body: some View {
        Text(String(StarterSessionActivity.shared.controller.activityCount))
            .font(.caption)
            .accessibilityIdentifier("timer.activityCount")
    }
}
#endif
