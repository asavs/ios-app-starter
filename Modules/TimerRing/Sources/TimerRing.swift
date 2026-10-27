import SwiftUI
import Theme

/// One ring that empties as a phase runs out, with the remaining time and the phase's title inside.
///
/// The ring only draws what it's given: pass a fraction and a remaining time from the app's clock
/// (`SessionSnapshot` in the SessionTimer module) on every update. It keeps no time of its own.
/// It's a single ring in the theme's accent, deliberately unlike Apple's concentric Activity
/// rings, which the HIG reserves for Move, Exercise and Stand.
///
/// VoiceOver reads it as one element: the title, then the remaining time ("Rest, 45 seconds
/// remaining"). The time is announced when someone moves to the ring, never on every update.
public struct TimerRing: View {
    let fractionRemaining: Double
    private let title: LocalizedStringResource
    private let remaining: Duration
    private let tint: Color?

    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var lineWidth = 14.0

    /// `fractionRemaining` runs from 1 (a full ring) to 0 and is clamped to that range. `tint`
    /// defaults to the theme's accent.
    public init(fractionRemaining: Double, title: LocalizedStringResource, remaining: Duration, tint: Color? = nil) {
        self.fractionRemaining = fractionRemaining.isFinite ? min(1, max(0, fractionRemaining)) : 0
        self.title = title
        self.remaining = remaining
        self.tint = tint
    }

    public var body: some View {
        let color = tint ?? theme.colors.accent
        let shown = Self.displayed(remaining)
        let spoken = shown.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        ZStack {
            Circle()
                .stroke(color.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fractionRemaining)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: theme.spacing.extraSmall) {
                Text(shown, format: .time(pattern: shown >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond))
                    .font(.system(.largeTitle, design: .rounded))
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.textPrimary)
                Text(title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            // Text inside a circle can't grow past it, so this is the one place that shrinks it.
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .padding(lineWidth * 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(spoken) remaining", bundle: .module))
    }

    /// A countdown shows whole seconds rounded up, so it reads 0:20 for the first second of a
    /// 20-second phase and reaches 0:00 only when the phase ends.
    static func displayed(_ remaining: Duration) -> Duration {
        let components = remaining.components
        guard components.seconds >= 0 else { return .zero }
        return .seconds(components.seconds + (components.attoseconds > 0 ? 1 : 0))
    }
}

#Preview("Timer ring") {
    VStack(spacing: 32) {
        TimerRing(fractionRemaining: 0.6, title: "Work", remaining: .seconds(12))
        TimerRing(fractionRemaining: 0.1, title: "Rest", remaining: .seconds(1.2), tint: .orange)
            .frame(width: 140)
    }
    .padding()
}
