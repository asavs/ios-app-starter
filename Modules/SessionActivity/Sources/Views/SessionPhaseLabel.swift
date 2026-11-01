#if os(iOS)
import SwiftUI
import Theme

/// The plan, the phase and its place in the session: "Intervals · Work, step 2 of 5".
struct SessionPhaseLabel: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityState
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(attributes.planTitle)
                .font(.headline)
            Text("\(state.phaseTitle), step \(String(state.phaseIndex + 1)) of \(String(state.phaseCount))", bundle: .module)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
