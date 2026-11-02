import SwiftUI
#if canImport(SessionTimer)

/// Skip and Reset; `TimerControls` arranges them.
struct TimerSecondaryButtons: View {
    let model: TimerScreenModel

    var body: some View {
        let status = model.timer.snapshot.status
        Button("Skip", systemImage: "forward.end", action: model.skip)
            .disabled(status == .ready || status == .finished)
            .accessibilityIdentifier(Identifiers.Timer.skip)
        Button("Reset", systemImage: "arrow.counterclockwise", action: model.reset)
            .disabled(status == .ready)
            .accessibilityIdentifier(Identifiers.Timer.reset)
    }
}
#endif
