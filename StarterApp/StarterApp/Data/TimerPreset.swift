import Foundation
#if canImport(Database)
import SwiftData

/// A saved timer plan: which plan and its times. `plan` is the `TimerPlan` raw value kept as text
/// so the store doesn't depend on the timer modules being enabled.
@Model
final class TimerPreset {
    var name: String
    var plan: String
    var work: Int
    var rest: Int
    var rounds: Int
    var createdAt: Date

    init(name: String, plan: String, work: Int, rest: Int, rounds: Int, createdAt: Date = .now) {
        self.name = name
        self.plan = plan
        self.work = work
        self.rest = rest
        self.rounds = rounds
        self.createdAt = createdAt
    }
}
#endif
