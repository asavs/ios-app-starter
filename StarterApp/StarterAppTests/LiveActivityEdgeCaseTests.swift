#if canImport(SessionTimer) && canImport(SessionActivity)
import Foundation
import SessionActivity
import SessionTimer
import Testing
@testable import StarterApp

/// The Timer screen, the stored record and the Live Activity together, through every change a
/// session can go through, against an isolated defaults suite, a controlled clock and a fake
/// ActivityKit. The screen's `onChange(of: snapshot)` is played by `step`.
@MainActor
struct LiveActivityEdgeCaseTests {
    private final class TestClock {
        var now = ContinuousClock.now
    }

    private let suiteName = "LiveActivityEdgeCaseTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let clock = TestClock()
    private let host = RecordingHost()
    private let activity: StarterSessionActivity

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        activity = StarterSessionActivity(defaults: defaults, host: host)
    }

    private func makeModel() -> TimerScreenModel {
        TimerScreenModel(defaults: defaults, activity: activity) { [clock] in clock.now }
    }

    /// Plays the screen: after `change`, the model hears the old and new snapshot as the view's
    /// `onChange` would pass them.
    private func step(_ model: TimerScreenModel, _ change: () -> Void) {
        let before = model.timer.snapshot
        change()
        model.sessionChanged(from: before, to: model.timer.snapshot)
    }

    private var record: SessionRecord? { SessionRecord.load(from: defaults) }

    // MARK: The session's changes

    @Test func everyChangeReachesTheRecordAndTheActivity() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel() // Intervals: 20 s work, 10 s rest, three rounds.
        step(model, model.primaryAction) // Start.
        #expect(record?.id == model.sessionID)
        #expect(record?.clock.isRunning == true)
        step(model) { clock.now += .seconds(5); model.primaryAction() } // Pause at 5 s.
        step(model, model.primaryAction) // Resume.
        step(model) { clock.now += .seconds(16); model.primaryAction() } // Pause at 21 s: into the rest.
        step(model, model.primaryAction) // Resume in the rest.
        step(model) { clock.now += .seconds(2); model.skip() } // Skip to the second work phase.
        step(model) { clock.now += .seconds(3600); model.skip() } // Reads the clock: finished.
        await activity.controller.drain()

        #expect(host.events.map(\.kind) == [.start, .update, .update, .update, .update, .update, .end])
        let states = host.events.compactMap(\.state)
        #expect(states.map(\.status) == [.running, .paused, .running, .paused, .running, .running, .finished])
        #expect(states.map(\.phaseIndex) == [0, 0, 0, 1, 1, 2, 4])
        #expect(states[1].pausedRemaining == .seconds(15))
        #expect(states[3].pausedRemaining == .seconds(9))
        #expect(host.events.last?.dismissal.map { $0 > .now.addingTimeInterval(14 * 60) } == true)
        #expect(record?.clock.isRunning == false, "The record outlives the finish, for the activity's 15 minutes")
        #expect(host.activityCount == 0)
    }

    @Test func aResetEndsTheActivityAtOnceAndClearsTheRecord() async {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        step(model, model.primaryAction)
        step(model, model.reset)
        await activity.controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end])
        #expect(host.events.last?.state == nil, "No final state: removed, not kept on the Lock Screen")
        #expect(record == nil)
        #expect(host.activityCount == 0)
    }

    @Test func startingAgainAfterFinishingIsANewSessionAndReplacesTheOldCard() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        step(model, model.primaryAction)
        let first = model.sessionID
        step(model) { clock.now += .seconds(3600); model.skip() }
        step(model, model.primaryAction) // "Start again".
        await activity.controller.drain()
        #expect(model.sessionID != first)
        #expect(host.events.map(\.kind) == [.start, .end, .end, .start])
        #expect(host.events[1].state?.status == .finished, "The finished card, kept 15 minutes")
        #expect(host.events[2].state == nil, "Then gone at once when the new session starts")
        #expect(host.sessionIDs == [model.sessionID])
        #expect(record?.id == model.sessionID)
    }

    // MARK: The setting

    @Test func theSettingOffEndsAtOnceAndOnShowsTheRunningSessionAtOnce() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        step(model, model.primaryAction)
        defaults.set(false, forKey: SessionActivityPreferences.enabledKey)
        activity.settingChanged()
        await activity.controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end])
        #expect(host.activityCount == 0)

        defaults.set(true, forKey: SessionActivityPreferences.enabledKey)
        activity.settingChanged()
        await activity.controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end, .start])
        #expect(host.events.last?.state?.status == .running)
        #expect(host.sessionIDs == [model.sessionID], "The same session's activity, not another's")
        #expect(model.timer.snapshot.status == .running, "The screen's session was never touched")
    }

    @Test func theSettingChangedWithoutASessionDoesNothing() async {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        activity.settingChanged()
        defaults.set(false, forKey: SessionActivityPreferences.enabledKey)
        activity.settingChanged()
        await activity.controller.drain()
        #expect(host.events.isEmpty)
    }

    @Test func aSessionStartedWithTheSettingOffHasNoActivityUntilItIsOn() async {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: SessionActivityPreferences.enabledKey)
        let model = makeModel()
        step(model, model.primaryAction)
        step(model) { clock.now += .seconds(21); model.primaryAction() } // A phase went by, paused.
        await activity.controller.drain()
        #expect(host.events.isEmpty)
        defaults.set(true, forKey: SessionActivityPreferences.enabledKey)
        activity.settingChanged()
        await activity.controller.drain()
        #expect(host.events.map(\.kind) == [.start])
        #expect(host.events.last?.state?.status == .paused && host.events.last?.state?.phaseIndex == 1,
                "Started with where the session is now")
    }

    // MARK: Launch

    @Test func aFreshModelAdoptsTheStoredSession() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let id = UUID()
        SessionRecord(id: id, plan: .focus, times: PlanTimes(work: 60, rest: 30, rounds: 2),
                      clock: SessionClockState(banked: .seconds(10), runningSince: .now.addingTimeInterval(-5), hasStarted: true))
            .save(to: defaults)
        let model = makeModel()
        #expect(model.sessionID == id, "The screen continues the session, not a new one beside it")
        #expect(model.plan == .focus)
        #expect(model.times == PlanTimes(work: 60, rest: 30, rounds: 2))
        #expect(model.timer.snapshot.status == .running)
        #expect(model.timer.snapshot.elapsed >= .seconds(15) && model.timer.snapshot.elapsed < .seconds(16))
        #expect(model.canChangePlan == false)
        #expect(defaults.string(forKey: "timer.focus") == "60,30,2", "Its times are the plan's stored times")
    }

    @Test func aFreshModelWithAFinishedOrUnreadableRecordStartsFromTheRecordOrFresh() throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        SessionRecord(id: UUID(), plan: .intervals, times: PlanTimes(work: 20, rest: 10, rounds: 3),
                      clock: SessionClockState(banked: .seconds(79), runningSince: .now.addingTimeInterval(-3600), hasStarted: true))
            .save(to: defaults)
        #expect(makeModel().timer.snapshot.status == .finished, "A session that ended while the app was away shows Done")

        var broken = try #require(record)
        broken.times = "not,times"
        broken.save(to: defaults)
        let fresh = makeModel()
        #expect(fresh.timer.snapshot.status == .ready)
        #expect(fresh.sessionID != broken.id)
    }

    @Test func reattachUpdatesTheStoredRunningSessionsActivity() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let id = UUID()
        host.existing = [id]
        SessionRecord(id: id, plan: .intervals, times: PlanTimes(work: 20, rest: 10, rounds: 3),
                      clock: SessionClockState(banked: .zero, runningSince: .now.addingTimeInterval(-4), hasStarted: true))
            .save(to: defaults)
        activity.reattach()
        await activity.controller.drain()
        #expect(host.events.map(\.kind) == [.update])
        let state = try #require(host.events.last?.state)
        #expect(state.status == .running && state.phaseIndex == 0)
        #expect(state.phase.map { $0.upperBound.timeIntervalSinceNow > 15 && $0.upperBound.timeIntervalSinceNow <= 16 } == true)
        #expect(host.activityCount == 1)
    }

    @Test func reattachEndsTheActivityOfASessionThatFinishedMeanwhile() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let id = UUID()
        host.existing = [id]
        SessionRecord(id: id, plan: .intervals, times: PlanTimes(work: 20, rest: 10, rounds: 3),
                      clock: SessionClockState(banked: .seconds(70), runningSince: .now.addingTimeInterval(-60), hasStarted: true))
            .save(to: defaults)
        activity.reattach()
        await activity.controller.drain()
        #expect(host.events.map(\.kind) == [.end])
        #expect(host.events.last?.state?.status == .finished)
        #expect(host.activityCount == 0)
    }

    @Test func reattachEndsActivitiesWhoseSessionIsGone() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let orphan = UUID()
        let id = UUID()
        host.existing = [orphan, id]
        SessionRecord(id: id, plan: .intervals, times: PlanTimes(work: 20, rest: 10, rounds: 3),
                      clock: SessionClockState(banked: .seconds(3), runningSince: nil, hasStarted: true))
            .save(to: defaults)
        activity.reattach()
        await activity.controller.drain()
        #expect(host.events.map(\.kind) == [.end, .update], "The orphan goes; the stored session's activity is updated")
        #expect(host.sessionIDs == [id])

        SessionRecord.clear(in: defaults) // Erase Local Data, or a reset in a process that never ran the end.
        activity.reattach()
        await activity.controller.drain()
        #expect(host.sessionIDs.isEmpty)
        #expect(host.activityCount == 0)
    }

    // MARK: The activity's button

    @Test func theButtonPausesAndResumesAndTheScreenOnShowFollows() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        step(model, model.primaryAction)
        clock.now += .seconds(5)
        await activity.toggle(model.sessionID)
        #expect(record?.clock.isRunning == false)
        #expect(host.events.last?.state?.status == .paused)
        #expect(model.timer.snapshot.status == .paused, "The island is visible in the foreground, so the screen follows at once")
        #expect(model.primaryTitle.key == "Resume")

        await activity.toggle(model.sessionID)
        #expect(record?.clock.isRunning == true)
        #expect(host.events.last?.state?.status == .running)
        #expect(model.timer.snapshot.status == .running)
        #expect(host.events.map(\.kind) == [.start, .update, .update])
    }

    @Test func theScreenFollowsTheRecordWhenTheAppReturns() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        step(model, model.primaryAction)
        // The button ran in a process without this screen: only the record changed.
        var paused = try #require(record)
        paused.clock = SessionClockState(banked: .seconds(7), runningSince: nil, hasStarted: true)
        paused.save(to: defaults)
        #expect(model.timer.snapshot.status == .running)
        model.restoreFromRecord()
        #expect(model.timer.snapshot.status == .paused)
        #expect(model.timer.snapshot.elapsed == .seconds(7))
        model.restoreFromRecord()
        #expect(model.timer.snapshot.elapsed == .seconds(7), "Nothing to do when the record agrees")
    }

    @Test func theButtonIgnoresAnotherSessionAndAFinishedOne() async throws {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        step(model, model.primaryAction)
        await activity.controller.drain()
        await activity.toggle(UUID())
        #expect(record?.clock.isRunning == true)
        #expect(model.timer.snapshot.status == .running)
        #expect(host.events.map(\.kind) == [.start])

        step(model) { clock.now += .seconds(3600); model.skip() } // Finished; the card stays 15 minutes.
        await activity.controller.drain()
        await activity.toggle(model.sessionID)
        #expect(record?.clock.isRunning == false, "A finished session doesn't start again from its button")
        #expect(host.events.map(\.kind) == [.start, .end], "Nothing to update: the activity has ended")
    }

    // MARK: Battery

    /// The screen refreshes ten times a second while a session runs; none of that may reach
    /// ActivityKit (the system counts the phase down itself) or the defaults store.
    @Test func ticksWithinAPhaseReachNeitherActivityKitNorTheRecord() async throws {
        let counting = try #require(CountingDefaults(suiteName: suiteName))
        defer { counting.removePersistentDomain(forName: suiteName) }
        let activity = StarterSessionActivity(defaults: counting, host: host)
        let model = TimerScreenModel(defaults: counting, activity: activity) { [clock] in clock.now }
        step(model, model.primaryAction)
        await activity.controller.drain()
        let writes = counting.writes
        let lookups = host.lookups
        #expect(host.events.count == 1)

        // What the view's onChange passes on each refresh: the same phase, less remaining.
        var mirror = SessionClock(plan: model.timer.plan)
        mirror.start(at: clock.now)
        var previous = mirror.snapshot(at: clock.now)
        for tick in 1...150 { // 15 s at 100 ms, all inside the 20 s work phase.
            let now = clock.now + .milliseconds(100 * tick)
            let next = mirror.snapshot(at: now)
            model.sessionChanged(from: previous, to: next)
            previous = next
        }
        await activity.controller.drain()
        #expect(host.events.count == 1, "No tick publishes to ActivityKit")
        #expect(host.lookups == lookups, "No tick asks ActivityKit anything")
        #expect(counting.writes == writes, "No tick writes the record")

        let boundary = mirror.snapshot(at: clock.now + .seconds(20))
        model.sessionChanged(from: previous, to: boundary)
        await activity.controller.drain()
        #expect(host.events.count == 2, "A phase change is one update")
        #expect(counting.writes == writes + 1, "And one record save")
    }
}

/// Counts writes, to show the record isn't saved on every tick.
private final class CountingDefaults: UserDefaults, @unchecked Sendable {
    var writes = 0

    override func set(_ value: Any?, forKey defaultName: String) {
        writes += 1
        super.set(value, forKey: defaultName)
    }
}

/// Records what the app asks of ActivityKit. Like `Activity.activities`, an ended activity with a
/// final state stays listed until its dismissal; one ended at once is gone.
@MainActor
private final class RecordingHost: SessionActivityHost {
    struct Event {
        enum Kind { case start, update, end }
        let kind: Kind
        let state: SessionActivityState?
        var dismissal: Date?
    }

    var areActivitiesEnabled = true
    var existing: [UUID] = []
    var ended: Set<UUID> = []
    var events: [Event] = []
    /// Every question asked of ActivityKit; each one enumerates `Activity.activities` for real.
    var lookups = 0

    var activityCount: Int {
        lookups += 1
        return existing.filter { !ended.contains($0) }.count
    }

    var sessionIDs: [UUID] {
        lookups += 1
        return existing
    }

    func hasActivity(for sessionID: UUID) -> Bool {
        lookups += 1
        return existing.contains(sessionID) && !ended.contains(sessionID)
    }

    func start(_ attributes: SessionActivityAttributes, state: SessionActivityState) throws {
        events.append(Event(kind: .start, state: state))
        existing.append(attributes.sessionID)
    }

    func update(sessionID: UUID, state: SessionActivityState) async {
        events.append(Event(kind: .update, state: state))
    }

    func end(sessionID: UUID, state: SessionActivityState?, dismissal: Date) async {
        events.append(Event(kind: .end, state: state, dismissal: dismissal))
        if state == nil {
            existing.removeAll { $0 == sessionID }
            ended.remove(sessionID)
        } else {
            ended.insert(sessionID)
        }
    }
}
#endif
