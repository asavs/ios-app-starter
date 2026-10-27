import Foundation

/// One plan's phase lengths and rounds, stored as "work,rest,rounds" seconds.
struct PlanTimes: Equatable, RawRepresentable {
    static let roundRange = 1...20

    private(set) var work: Int
    private(set) var rest: Int
    var rounds: Int {
        didSet { rounds = rounds.clamped(to: Self.roundRange) }
    }

    init(work: Int, rest: Int, rounds: Int) {
        self.work = max(1, work)
        self.rest = max(1, rest)
        self.rounds = rounds.clamped(to: Self.roundRange)
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ",").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(work: parts[0], rest: parts[1], rounds: parts[2])
    }

    var rawValue: String { "\(work),\(rest),\(rounds)" }

    /// The work length for a duration picker; whole seconds, at least one.
    var workDuration: Duration {
        get { .seconds(work) }
        set { work = max(1, Int(newValue.components.seconds)) }
    }

    var restDuration: Duration {
        get { .seconds(rest) }
        set { rest = max(1, Int(newValue.components.seconds)) }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}
