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

#Preview("Buttons") {
    VStack(spacing: 12) {
        Button("Continue") {}.buttonStyle(.primary)
        Button("Not now") {}.buttonStyle(.secondary)
        Button("Disabled") {}.buttonStyle(.primary).disabled(true)
    }
    .padding()
}
