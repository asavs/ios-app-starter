#if os(iOS)
import SwiftUI

/// The phase's remaining time: counted down by the system while running, frozen while paused,
/// 0:00 once the phase is over and the app hasn't published the next one, and "Done" at the end.
///
/// Timer text in a widget grows to fill its width, so callers give it a frame.
struct SessionCountdownText: View {
    let state: SessionActivityState
    let isStale: Bool

    var body: some View {
        Group {
            switch state.status {
            case .running where isStale == false:
                if let phase = state.phase {
                    Text(timerInterval: phase, countsDown: true, showsHours: state.phaseDuration >= .seconds(3600))
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(Self.formatted(.zero))
                }
            case .running:
                Text(Self.formatted(.zero))
            case .paused:
                Text(Self.formatted(state.pausedRemaining ?? .zero))
            case .finished:
                Text("Done", bundle: .module)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .contentTransition(.numericText(countsDown: true))
    }

    static func formatted(_ duration: Duration) -> String {
        duration.formatted(.time(pattern: duration >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond))
    }
}
#endif
