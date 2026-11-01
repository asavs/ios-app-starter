#if os(iOS)
import SwiftUI

/// "Ends at 3:42 PM" while running (one date; it needs no update), "Paused" while paused, a hint
/// to open the app once the phase is over, and "Done" at the end.
struct SessionEndLabel: View {
    let state: SessionActivityState
    let isStale: Bool

    var body: some View {
        Group {
            switch state.status {
            case .running where isStale:
                Text("Phase over. Open the app for the next one.", bundle: .module)
            case .running:
                HStack(spacing: 4) {
                    Text("Ends at", bundle: .module)
                    Text(state.sessionEnd, style: .time)
                }
            case .paused:
                Text("Paused", bundle: .module)
            case .finished:
                Text("Session done", bundle: .module)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
}
#endif
