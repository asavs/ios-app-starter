import SwiftUI
#if canImport(TabShell)

/// One feature in the chooser: a control to hide or show it, then its symbol, name and one sentence.
/// The move actions are the way to reorder without dragging.
struct TabChoiceRow: View {
    enum Control {
        case hide(() -> Void)
        case show(() -> Void)
        /// A required feature: nothing to press.
        case alwaysShown
    }

    let feature: StarterFeature
    let control: Control
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var symbolWidth = 28
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At the accessibility sizes the symbols in a line leave the text room for a few letters a
        // line, breaking words: the control goes above the text and the decorative symbol goes.
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            controlView
            HStack(spacing: 12) {
                if !stacked {
                    Image(systemName: feature.systemImage)
                        .foregroundStyle(.tint)
                        .frame(width: symbolWidth)
                        .accessibilityHidden(true) // The name says it.
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                    Text(feature.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(isAlwaysShown ? Text("Always shown") : Text(verbatim: ""))
            .accessibilityActions {
                if let moveUp { Button("Move Up", action: moveUp) }
                if let moveDown { Button("Move Down", action: moveDown) }
            }
        }
    }

    private var isAlwaysShown: Bool {
        if case .alwaysShown = control { true } else { false }
    }

    @ViewBuilder private var controlView: some View {
        switch control {
        case .hide(let action):
            button("Hide \(String(localized: feature.title))", symbol: "minus.circle.fill", color: .red, action: action)
                .accessibilityIdentifier(Identifiers.TabChoices.hide(feature.id.rawValue))
        case .show(let action):
            button("Show \(String(localized: feature.title))", symbol: "plus.circle.fill", color: .green, action: action)
                .accessibilityIdentifier(Identifiers.TabChoices.show(feature.id.rawValue))
        case .alwaysShown:
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHidden(true) // The row's value says it.
        }
    }

    /// Borderless, so that only the symbol takes the tap rather than the whole row, and at least 44
    /// points each way. The symbols differ, so the colors aren't the only difference.
    private func button(_ title: LocalizedStringKey, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, color)
            }
            .labelStyle(.iconOnly)
            .imageScale(.large)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
    }
}
#endif
