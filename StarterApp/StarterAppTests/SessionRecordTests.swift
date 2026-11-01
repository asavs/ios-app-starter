#if canImport(SessionTimer)
import Foundation
import SessionTimer
import Testing
@testable import StarterApp

/// The stored session: what the Timer screen writes and the Live Activity's intent reads.
@MainActor
struct SessionRecordTests {
    private final class TestClock {
        var now = ContinuousClock.now
    }

    private let suiteName = "SessionRecordTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let clock = TestClock()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    private func makeModel() -> TimerScreenModel {
        TimerScreenModel(defaults: defaults, plan: .intervals) { [clock] in clock.now }
    }

    /// Drive the model the way the view does: each snapshot change reaches `sessionChanged`.
    private func change(_ model: TimerScreenModel, _ action: () -> Void) {
        let old = model.timer.snapshot
        action()
        model.sessionChanged(from: old, to: model.timer.snapshot)
    }

    @Test func roundTripsThroughDefaults() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let record = SessionRecord(id: UUID(), plan: .focus, times: PlanTimes(work: 1500, rest: 300, rounds: 4),
                                   clock: SessionClockState(banked: .seconds(42), runningSince: nil, hasStarted: true))
        record.save(to: defaults)
        #expect(SessionRecord.load(from: defaults) == record)
        #expect(try #require(record.sessionPlan).phases.count == 7)
        SessionRecord.clear(in: defaults)
        #expect(SessionRecord.load(from: defaults) == nil)
    }

    @Test func theModelKeepsTheRecordCurrentAndClearsItOnReset() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        change(model) { model.primaryAction() }
        let running = SessionRecord.load(from: defaults)
        #expect(running?.id == model.sessionID)
        #expect(running?.plan == .intervals)
        #expect(running?.clock.isRunning == true)

        change(model) { model.primaryAction() }
        #expect(SessionRecord.load(from: defaults)?.clock.isRunning == false)

        let before = model.sessionID
        change(model) { model.reset() }
        #expect(SessionRecord.load(from: defaults) == nil)
        #expect(model.sessionID == before, "The reset still names the session it ends")
        change(model) { model.primaryAction() }
        #expect(model.sessionID != before, "The next start is a new session")
        #expect(SessionRecord.load(from: defaults)?.id == model.sessionID)
    }

    @Test func restoringTakesAnIntentsPauseOver() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        change(model) { model.primaryAction() }
        // The activity's button paused the session 5 s in, while the app was in the background.
        var record = SessionRecord.load(from: defaults)!
        record.clock = SessionClockState(banked: .seconds(5), runningSince: nil, hasStarted: true)
        record.save(to: defaults)

        model.restoreFromRecord()
        #expect(model.timer.snapshot.status == .paused)
        #expect(model.timer.snapshot.elapsed == .seconds(5))
    }

    @Test func restoringIgnoresAnotherSessionsRecord() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        change(model) { model.primaryAction() }
        SessionRecord(id: UUID(), plan: .intervals, times: model.times,
                      clock: SessionClockState(banked: .zero, runningSince: nil, hasStarted: true)).save(to: defaults)
        model.restoreFromRecord()
        #expect(model.timer.snapshot.status == .running)
    }
}
#endif
