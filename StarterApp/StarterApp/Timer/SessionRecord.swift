import Foundation
#if canImport(SessionTimer)
import SessionTimer

/// The session underway, as stored values: which plan, its times and where the clock is, as dates.
///
/// `TimerScreenModel` saves it on every change and clears it when the session resets. An App
/// Intent from the Live Activity (pause or resume) runs in the app's process while no screen
/// exists, so it works on this record; the Timer screen picks the change up when it returns.
struct SessionRecord: Codable, Equatable {
    static let key = "timer.session"

    var id: UUID
    var plan: TimerPlan
    /// `PlanTimes.rawValue`.
    var times: String
    var clock: SessionClockState

    init(id: UUID, plan: TimerPlan, times: PlanTimes, clock: SessionClockState) {
        self.id = id
        self.plan = plan
        self.times = times.rawValue
        self.clock = clock
    }

    /// The plan's phases, or nil for times that no longer parse.
    var sessionPlan: SessionPlan? {
        PlanTimes(rawValue: times).map(plan.session)
    }

    static func load(from defaults: UserDefaults) -> SessionRecord? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(SessionRecord.self, from: $0) }
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    static func clear(in defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

extension TimerPlan: Codable {}
#endif
