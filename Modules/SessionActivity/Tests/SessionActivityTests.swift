import Foundation
import SessionTimer
import Testing
@testable import SessionActivity

@MainActor
struct SessionActivityTests {
    private let t0 = ContinuousClock.now
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    // 20 s work, 10 s rest, two rounds: work, rest, work = 50 s.
    private let plan = SessionPlan.intervals(
        work: SessionPhase(kind: "work", title: "Work", duration: .seconds(20)),
        rest: SessionPhase(kind: "rest", title: "Rest", duration: .seconds(10)),
        rounds: 2)
    private let attributes = SessionActivityAttributes(planTitle: "Intervals", sessionID: UUID(),
                                                       link: URL(string: "starterapp://timer"))

    private func snapshot(after seconds: Int, paused: Bool = false) -> SessionSnapshot {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        if paused { clock.pause(at: t0 + .seconds(seconds)) }
        return clock.snapshot(at: t0 + .seconds(seconds))
    }

    @Test func aReadySessionHasNoState() {
        #expect(SessionActivityState(SessionClock(plan: plan).snapshot(at: t0), plan: plan, now: date) == nil)
    }

    @Test func aRunningPhaseBecomesADateRangeTheSystemCountsDown() throws {
        let state = try #require(SessionActivityState(snapshot(after: 25), plan: plan, now: date))
        #expect(state.status == .running)
        #expect(state.phaseIndex == 1)
        #expect(state.phaseCount == 3)
        #expect(state.phaseTitle == "Rest")
        #expect(state.phaseKind == "rest")
        #expect(state.phaseDuration == .seconds(10))
        #expect(state.phase == date.addingTimeInterval(-5)...date.addingTimeInterval(5))
        #expect(state.pausedRemaining == nil)
        #expect(state.sessionEnd == date.addingTimeInterval(25))
        #expect(state.staleDate == date.addingTimeInterval(5), "Stale when the phase ends")
        #expect(state.pausedFractionRemaining == 1)
    }

    @Test func aPausedPhaseKeepsItsRemainingTime() throws {
        let state = try #require(SessionActivityState(snapshot(after: 5, paused: true), plan: plan, now: date))
        #expect(state.status == .paused)
        #expect(state.phase == nil)
        #expect(state.pausedRemaining == .seconds(15))
        #expect(state.pausedFractionRemaining == 0.75)
        #expect(state.sessionEnd == date.addingTimeInterval(45))
        #expect(state.staleDate == nil)
    }

    @Test func aFinishedSessionEndsNow() throws {
        let state = try #require(SessionActivityState(snapshot(after: 50), plan: plan, now: date))
        #expect(state.status == .finished)
        #expect(state.phaseIndex == 2)
        #expect(state.sessionEnd == date)
        #expect(state.pausedFractionRemaining == 0)
    }

    @Test func stateEncodesWellUnderTheFourKilobyteLimit() throws {
        let encoded = try JSONEncoder().encode(SessionActivityState.previewRunning)
        #expect(encoded.count < 1024)
        let decoded = try JSONDecoder().decode(SessionActivityState.self, from: encoded)
        #expect(decoded.status == .running)
        #expect(decoded.phaseTitle == "Rest")
        let attributes = try JSONEncoder().encode(self.attributes)
        #expect(attributes.count < 512)
    }

    @Test func preferencesDefaultToEnabled() throws {
        let suite = "SessionActivityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(SessionActivityPreferences(defaults: defaults).isEnabled)
        defaults.set(false, forKey: SessionActivityPreferences.enabledKey)
        #expect(SessionActivityPreferences(defaults: defaults).isEnabled == false)
        _ = SessionActivitySettingsSection(defaults: defaults)
    }

    // MARK: Controller

    @Test func startsOnceThenUpdatesAndEnds() async {
        let host = RecordingHost()
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        controller.sessionChanged(snapshot(after: 25), plan: plan, attributes: attributes)
        controller.sessionChanged(snapshot(after: 50), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .update, .end])
        #expect(host.events[0].state?.phaseIndex == 0)
        #expect(host.events[1].state?.phaseIndex == 1)
        #expect(host.events[2].state?.status == .finished)
        #expect(host.events[2].dismissal == date.addingTimeInterval(15 * 60), "A finished session stays a while")
        #expect(host.activityCount == 0)
    }

    @Test func aResetEndsTheActivityAtOnce() async {
        let host = RecordingHost()
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        controller.sessionChanged(SessionClock(plan: plan).snapshot(at: t0), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end])
        #expect(host.events[1].state == nil)
        #expect(host.events[1].dismissal == date, "No final state: remove it immediately")
    }

    @Test func doesNothingWhenOffOrDisallowed() async {
        let host = RecordingHost()
        var enabled = false
        let controller = SessionActivityController(host: host, isEnabled: { enabled }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.isEmpty)

        enabled = true
        host.areActivitiesEnabled = false
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.isEmpty, "Live Activities turned off for the app in Settings")
    }

    @Test func turningTheSettingOffRemovesTheActivity() async {
        let host = RecordingHost()
        var enabled = true
        let controller = SessionActivityController(host: host, isEnabled: { enabled }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        enabled = false
        controller.settingChanged(sessionID: attributes.sessionID)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end])
        // And a later change starts nothing.
        controller.sessionChanged(snapshot(after: 2), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.count == 2)
    }

    @Test func aRefusedStartIsNotRetriedEveryTick() async {
        let host = RecordingHost()
        host.refusesStarts = true
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        controller.sessionChanged(snapshot(after: 2), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .start], "Each change tries once; nothing to update")
        #expect(host.activityCount == 0)
    }

    @Test func anActivityFromAnEarlierLaunchIsUpdated() async {
        let host = RecordingHost()
        host.existing.insert(attributes.sessionID)
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 5, paused: true), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.update])
        #expect(controller.activityCount == 1)
    }
}

/// Records what the controller asks of ActivityKit.
@MainActor
private final class RecordingHost: SessionActivityHost {
    struct Event {
        enum Kind { case start, update, end }
        let kind: Kind
        let state: SessionActivityState?
        var dismissal: Date?
    }

    struct Refused: Error {}

    var areActivitiesEnabled = true
    var refusesStarts = false
    var existing: Set<UUID> = []
    var events: [Event] = []

    var activityCount: Int { existing.count }

    func hasActivity(for sessionID: UUID) -> Bool { existing.contains(sessionID) }

    func start(_ attributes: SessionActivityAttributes, state: SessionActivityState) throws {
        events.append(Event(kind: .start, state: state))
        if refusesStarts { throw Refused() }
        existing.insert(attributes.sessionID)
    }

    func update(sessionID: UUID, state: SessionActivityState) async {
        events.append(Event(kind: .update, state: state))
    }

    func end(sessionID: UUID, state: SessionActivityState?, dismissal: Date) async {
        events.append(Event(kind: .end, state: state, dismissal: dismissal))
        existing.remove(sessionID)
    }
}
