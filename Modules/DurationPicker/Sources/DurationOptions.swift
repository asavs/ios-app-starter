import Foundation

/// The wheels' choices and the arithmetic behind them, separate from the view so it can be tested.
public struct DurationOptions: Equatable, Sendable {
    /// 23:59:59, the Clock app's longest timer, in seconds.
    public static let longest = 24 * 60 * 60 - 1

    struct Parts: Equatable, Sendable {
        var hours: Int
        var minutes: Int
        var seconds: Int
    }

    let range: ClosedRange<Duration>
    let step: Int

    init(range: ClosedRange<Duration>, step: Duration) {
        let limit = Duration.seconds(Self.longest)
        let lower = min(max(range.lowerBound, .zero), limit)
        self.range = lower ... max(lower, min(range.upperBound, limit))
        let stepSeconds = Int(step.components.seconds)
        self.step = stepSeconds > 0 && 60 % stepSeconds == 0 ? stepSeconds : 1
    }

    private var upper: Int { Self.wholeSeconds(range.upperBound) }

    /// Empty when the range stays under an hour, which hides the hours wheel.
    var hours: [Int] { upper >= 3600 ? Array(0 ... upper / 3600) : [] }
    var minutes: [Int] { upper >= 3600 ? Array(0...59) : Array(0 ... upper / 60) }
    var seconds: [Int] { Array(stride(from: 0, to: 60, by: step)) }

    /// Inside the range and on a step, rounding to the nearest step.
    func clamped(_ value: Duration) -> Duration {
        let total = Self.wholeSeconds(min(max(value, range.lowerBound), range.upperBound))
        let snapped = Int((Double(total) / Double(step)).rounded()) * step
        let stepped = Duration.seconds(snapped)
        if stepped > range.upperBound { return .seconds(snapped - step) }
        if stepped < range.lowerBound { return .seconds(snapped + step) }
        return stepped
    }

    func split(_ value: Duration) -> Parts {
        let total = Self.wholeSeconds(value)
        return Parts(hours: total / 3600, minutes: total % 3600 / 60, seconds: total % 60)
    }

    func combined(_ parts: Parts) -> Duration {
        clamped(.seconds(parts.hours * 3600 + parts.minutes * 60 + parts.seconds))
    }

    private static func wholeSeconds(_ value: Duration) -> Int { Int(value.components.seconds) }
}
