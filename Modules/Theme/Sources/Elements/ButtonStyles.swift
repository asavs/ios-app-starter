import SwiftUI

/// Filled, full-width call to action: `Button("Continue") {}.buttonStyle(.primary)`.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.headline)
            .foregroundStyle(theme.colors.onAccent)
            .padding(.vertical, theme.spacing.medium - theme.spacing.extraSmall)
            .padding(.horizontal, theme.spacing.medium)
            .frame(maxWidth: .infinity)
            .background(theme.colors.accent.opacity(isEnabled ? 1 : 0.4),
                        in: .rect(cornerRadius: theme.radii.medium))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined, full-width secondary action: `Button("Not now") {}.buttonStyle(.secondary)`.
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.headline)
            .foregroundStyle(theme.colors.accent.opacity(isEnabled ? 1 : 0.4))
            .padding(.vertical, theme.spacing.medium - theme.spacing.extraSmall)
            .padding(.horizontal, theme.spacing.medium)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.radii.medium)
                    .strokeBorder(theme.colors.accent.opacity(isEnabled ? 1 : 0.4), lineWidth: 1.5)
            )
            .contentShape(.rect(cornerRadius: theme.radii.medium)) // The stroke alone leaves the padding untappable.
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

public extension View {
    /// A screen's main call to action: Liquid Glass (`.glassProminent`, large) on iOS 26 and later,
    /// `.primary` before, so every prominent button in an app has the same shape. Give the label
    /// `.frame(maxWidth: .infinity)` for a full-width button; the glass style sizes to its label.
    func prominentButtonStyle() -> some View {
        modifier(ProminentButtonStyle())
    }
}

private struct ProminentButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        // `#available` does not hide a symbol the SDK lacks: Xcode 16 (Swift 6.0) has no `.glassProminent`.
        #if compiler(>=6.2)
        if #available(iOS 26, macOS 26, *) {
            content
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            content
                .buttonStyle(.primary)
        }
        #else
        content
            .buttonStyle(.primary)
        #endif
    }
}

#Preview("Buttons") {
    VStack(spacing: 12) {
        Button("Continue") {}.buttonStyle(.primary)
        Button("Not now") {}.buttonStyle(.secondary)
        Button("Disabled") {}.buttonStyle(.primary).disabled(true)
        Button {} label: { Text("Prominent").frame(maxWidth: .infinity) }.prominentButtonStyle()
    }
    .padding()
}
