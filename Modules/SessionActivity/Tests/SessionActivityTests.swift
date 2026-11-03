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

    @Test func turningTheSettingOnStartsTheActivityOnTheNextChange() async {
        let host = RecordingHost()
        var enabled = false
        let controller = SessionActivityController(host: host, isEnabled: { enabled }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.isEmpty, "A session started with the setting off has no activity")
        enabled = true
        // The app re-sends the running session when the setting changes; the same call a tick makes.
        controller.sessionChanged(snapshot(after: 2), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start])
        #expect(controller.activityCount == 1)
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
        host.existing.append(attributes.sessionID)
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 5, paused: true), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.update])
        #expect(controller.activityCount == 1)
    }

    // MARK: Edge cases: sequencing

    @Test func everyPhaseBoundarySkipAndPauseIsOneUpdateWithTheRightPhase() async throws {
        let host = RecordingHost()
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        func send(at seconds: Int) {
            controller.sessionChanged(clock.snapshot(at: t0 + .seconds(seconds)), plan: plan, attributes: attributes)
        }
        send(at: 0) // Start: work.
        send(at: 20) // The boundary belongs to the rest phase.
        clock.pause(at: t0 + .seconds(25))
        send(at: 25) // Paused mid-rest.
        clock.start(at: t0 + .seconds(40))
        send(at: 40) // Resumed: 5 s of rest left.
        clock.skipToNextPhase(at: t0 + .seconds(42))
        send(at: 42) // Skipped to the last work phase.
        send(at: 62) // Finished (20 s of work after the skip).
        await controller.drain()

        #expect(host.events.map(\.kind) == [.start, .update, .update, .update, .update, .end])
        let states = host.events.compactMap(\.state)
        #expect(states.map(\.phaseIndex) == [0, 1, 1, 1, 2, 2])
        #expect(states.map(\.status) == [.running, .running, .paused, .running, .running, .finished])
        let rest = try #require(states[1].phase)
        #expect(rest == date...date.addingTimeInterval(10), "A boundary starts the next phase in full")
        #expect(states[2].pausedRemaining == .seconds(5))
        #expect(states[3].phase == date.addingTimeInterval(-5)...date.addingTimeInterval(5))
        #expect(states[4].phase == date...date.addingTimeInterval(20), "A skip starts the next phase in full")
        #expect(states[5].sessionEnd == date)
        #expect(host.events[5].dismissal == date.addingTimeInterval(15 * 60))
        #expect(host.activityCount == 0)
    }

    @Test func aPhaseThatEndsWithoutAChangeOnlyGoesStale() async throws {
        // The design's limit: nothing runs in the app when a phase ends in the background, so the
        // activity's content stays what the last change published and the system marks it stale at
        // the phase's end. The view then shows 0:00 until the app publishes the next phase.
        let host = RecordingHost()
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        await controller.drain()
        let published = try #require(host.events.last?.state)
        #expect(published.staleDate == date.addingTimeInterval(19), "Stale exactly when the work phase ends")
        #expect(published.sessionEnd == date.addingTimeInterval(49), "The session end is the one date that stays right")
        #expect(host.events.count == 1, "No change, no update: the next phase is published by the app's next run")
    }

    @Test func rapidPauseAndResumeArriveInOrder() async throws {
        let host = RecordingHost()
        host.updateDelays = [.milliseconds(60), .zero, .zero]
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        controller.sessionChanged(snapshot(after: 2, paused: true), plan: plan, attributes: attributes)
        controller.sessionChanged(snapshot(after: 3), plan: plan, attributes: attributes)
        controller.sessionChanged(snapshot(after: 4, paused: true), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .update, .update, .update])
        #expect(host.events.compactMap(\.state).map(\.status) == [.running, .paused, .running, .paused],
                "A slow first update doesn't let the later ones overtake it")
    }

    @Test func turningTheSettingOffThenOnStartsAgain() async {
        let host = RecordingHost()
        var enabled = true
        let controller = SessionActivityController(host: host, isEnabled: { enabled }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        enabled = false
        controller.sessionChanged(snapshot(after: 2), plan: plan, attributes: attributes)
        enabled = true
        controller.sessionChanged(snapshot(after: 3), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end, .start])
        #expect(host.events[1].state == nil && host.events[1].dismissal == date, "Off: removed at once")
        #expect(controller.activityCount == 1, "On again: one activity, counted")
    }

    @Test func systemPermissionGrantedLaterStartsOnTheNextChange() async {
        let host = RecordingHost()
        host.areActivitiesEnabled = false
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        host.areActivitiesEnabled = true
        controller.sessionChanged(snapshot(after: 2), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start])
    }

    @Test func aRefusedStartIsRetriedOnTheNextRealChange() async {
        let host = RecordingHost()
        host.refusesStarts = true
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        await controller.drain()
        host.refusesStarts = false // The app came to the foreground.
        controller.sessionChanged(snapshot(after: 2, paused: true), plan: plan, attributes: attributes)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .start])
        #expect(host.events[1].state?.status == .paused, "Started with the current state, not the refused one")
        #expect(controller.activityCount == 1)
    }

    @Test func pausedAtZeroAndFinishedExactlyAtTheEndMapCleanly() throws {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        clock.pause(at: t0)
        let pausedAtStart = try #require(SessionActivityState(clock.snapshot(at: t0), plan: plan, now: date))
        #expect(pausedAtStart.status == .paused)
        #expect(pausedAtStart.pausedRemaining == .seconds(20))
        #expect(pausedAtStart.pausedFractionRemaining == 1)

        clock.start(at: t0)
        let lastInstant = try #require(SessionActivityState(clock.snapshot(at: t0 + .seconds(49)), plan: plan, now: date))
        #expect(lastInstant.status == .running && lastInstant.phaseIndex == 2)
        #expect(lastInstant.phase == date.addingTimeInterval(-19)...date.addingTimeInterval(1))
        let atEnd = try #require(SessionActivityState(clock.snapshot(at: t0 + .seconds(50)), plan: plan, now: date))
        #expect(atEnd.status == .finished && atEnd.phaseIndex == 2)
        #expect(atEnd.phase == nil && atEnd.staleDate == nil && atEnd.sessionEnd == date)
    }

    @Test func longTitlesStayUnderTheFourKilobyteLimit() throws {
        let longTitle = String(repeating: "A rather long phase title ", count: 8) // 208 characters.
        let state = SessionActivityState(status: .running, phaseIndex: 99, phaseCount: 100, phaseTitle: longTitle,
                                         phaseKind: String(repeating: "k", count: 100), phaseDuration: .seconds(86_400),
                                         phase: date...date.addingTimeInterval(86_400), pausedRemaining: nil,
                                         sessionEnd: date.addingTimeInterval(86_400 * 100))
        #expect(try JSONEncoder().encode(state).count < 4096)
        let attributes = SessionActivityAttributes(planTitle: String(repeating: "Plan ", count: 50), sessionID: UUID(),
                                                   link: URL(string: "starterapp://timer?preset=\(String(repeating: "x", count: 200))"))
        #expect(try JSONEncoder().encode(attributes).count < 1024)
    }

    // MARK: The schedule and the stale render

    @Test func upcomingPhasesFollowTheCurrentOneBackToBack() throws {
        let state = try #require(SessionActivityState(snapshot(after: 5), plan: plan, now: date))
        #expect(state.phase == date.addingTimeInterval(-5)...date.addingTimeInterval(15))
        #expect(state.upcoming == [
            SessionActivityState.ScheduledPhase(index: 1, title: "Rest", kind: "rest",
                                                range: date.addingTimeInterval(15)...date.addingTimeInterval(25)),
            SessionActivityState.ScheduledPhase(index: 2, title: "Work", kind: "work",
                                                range: date.addingTimeInterval(25)...date.addingTimeInterval(45)),
        ])
        #expect(state.upcoming.last?.range.upperBound == state.sessionEnd, "The schedule ends where the session does")
        let lastPhase = try #require(SessionActivityState(snapshot(after: 35), plan: plan, now: date))
        #expect(lastPhase.upcoming.isEmpty)
    }

    @Test func upcomingIsEmptyWhilePausedOrFinished() throws {
        let paused = try #require(SessionActivityState(snapshot(after: 5, paused: true), plan: plan, now: date))
        #expect(paused.upcoming.isEmpty)
        let finished = try #require(SessionActivityState(snapshot(after: 60), plan: plan, now: date))
        #expect(finished.status == .finished && finished.upcoming.isEmpty)
    }

    @Test func upcomingIsCappedAndStaysUnderFourKilobytesWithLongTitles() throws {
        let longTitle = String(repeating: "A rather long phase title ", count: 8) // 208 characters.
        let long = SessionPlan.intervals(
            work: SessionPhase(kind: String(repeating: "k", count: 100), title: "\(longTitle)", duration: .seconds(86_400)),
            rest: SessionPhase(kind: String(repeating: "r", count: 100), title: "\(longTitle)", duration: .seconds(86_400)),
            rounds: 30)
        var clock = SessionClock(plan: long)
        clock.start(at: t0)
        let state = try #require(SessionActivityState(clock.snapshot(at: t0 + .seconds(1)), plan: long, now: date))
        #expect(state.upcoming.count == SessionActivityState.upcomingLimit)
        #expect(state.upcoming.first?.index == 1 && state.upcoming.last?.index == SessionActivityState.upcomingLimit)
        #expect(try JSONEncoder().encode(state).count < 4096)
    }

    @Test func aStaleRenderShowsTheNextPhaseThenTheFinish() throws {
        let state = try #require(SessionActivityState(snapshot(after: 5), plan: plan, now: date))
        let fresh = state.shown(at: date.addingTimeInterval(10), isStale: false)
        #expect(fresh.state == state && fresh.isStale == false, "Nothing changes while the system still counts")

        let early = state.shown(at: date.addingTimeInterval(14.9), isStale: true)
        #expect(early.state == state && early.isStale == false, "A render a moment early keeps counting the same phase")

        let rest = state.shown(at: date.addingTimeInterval(15.5), isStale: true)
        #expect(rest.isStale == false)
        #expect(rest.state.status == .running && rest.state.phaseIndex == 1 && rest.state.phaseTitle == "Rest" && rest.state.phaseKind == "rest")
        #expect(rest.state.phase == date.addingTimeInterval(15)...date.addingTimeInterval(25))
        #expect(rest.state.phaseDuration == .seconds(10))
        #expect(rest.state.sessionEnd == state.sessionEnd)
        #expect(rest.state.upcoming.map(\.index) == [2], "The schedule moves on with the phase")
        #expect(rest.state.staleDate == date.addingTimeInterval(25))

        let work = state.shown(at: date.addingTimeInterval(30), isStale: true)
        #expect(work.state.phaseIndex == 2 && work.state.upcoming.isEmpty && work.isStale == false)

        let done = state.shown(at: date.addingTimeInterval(45), isStale: true)
        #expect(done.state.status == .finished && done.state.phase == nil && done.state.phaseIndex == 2 && done.isStale == false)
        #expect(done.state.sessionEnd == state.sessionEnd)
    }

    @Test func aStaleRenderPastTheScheduleSaysThePhaseIsOver() throws {
        let long = SessionPlan.intervals(work: SessionPhase(kind: "work", title: "Work", duration: .seconds(20)),
                                         rest: SessionPhase(kind: "rest", title: "Rest", duration: .seconds(10)),
                                         rounds: 30)
        var clock = SessionClock(plan: long)
        clock.start(at: t0)
        let state = try #require(SessionActivityState(clock.snapshot(at: t0 + .seconds(1)), plan: long, now: date))
        let lastScheduled = try #require(state.upcoming.last)
        let beyond = state.shown(at: lastScheduled.range.upperBound.addingTimeInterval(1), isStale: true)
        #expect(beyond.state == state && beyond.isStale, "Beyond the eight carried phases the view says the phase is over")
        let paused = try #require(SessionActivityState(snapshot(after: 5, paused: true), plan: plan, now: date))
        #expect(paused.shown(at: date.addingTimeInterval(100), isStale: true).state == paused)
    }

    // MARK: Edge cases: other sessions' activities

    @Test func aNewSessionEndsTheOldSessionsActivityAtOnce() async {
        let host = RecordingHost()
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.sessionChanged(snapshot(after: 50), plan: plan, attributes: attributes) // No activity to end.
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: attributes)
        controller.sessionChanged(snapshot(after: 50), plan: plan, attributes: attributes) // Finished: a card for 15 min.
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end])

        host.existing.append(attributes.sessionID) // ActivityKit keeps an ended activity until it's dismissed.
        let next = SessionActivityAttributes(planTitle: "Intervals", sessionID: UUID(), link: nil)
        controller.sessionChanged(snapshot(after: 1), plan: plan, attributes: next)
        await controller.drain()
        #expect(host.events.map(\.kind) == [.start, .end, .end, .start])
        #expect(host.events[2].state == nil && host.events[2].dismissal == date, "The old card goes at once")
        #expect(host.existing == [next.sessionID])
        #expect(controller.activityCount == 1)
    }

    @Test func endingOthersOnLaunchKeepsOnlyTheStoredSession() async {
        let host = RecordingHost()
        let orphan = UUID()
        host.existing = [orphan, attributes.sessionID]
        let controller = SessionActivityController(host: host, isEnabled: { true }, now: { [date] in date })
        controller.endOthers(than: attributes.sessionID)
        await controller.drain()
        #expect(host.existing == [attributes.sessionID])
        #expect(host.events.map(\.kind) == [.end])

        controller.endOthers(than: nil) // No stored session: nothing stays.
        await controller.drain()
        #expect(host.existing.isEmpty)
        #expect(controller.activityCount == 0)
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
    /// In the order they were started, like `Activity.activities`.
    var existing: [UUID] = []
    var events: [Event] = []
    /// How long each update takes, in order; an update past the end is immediate.
    var updateDelays: [Duration] = []

    var activityCount: Int { existing.count }
    var sessionIDs: [UUID] { existing }

    func hasActivity(for sessionID: UUID) -> Bool { existing.contains(sessionID) }

    func start(_ attributes: SessionActivityAttributes, state: SessionActivityState) throws {
        events.append(Event(kind: .start, state: state))
        if refusesStarts { throw Refused() }
        existing.append(attributes.sessionID)
    }

    func update(sessionID: UUID, state: SessionActivityState) async {
        if !updateDelays.isEmpty {
            try? await Task.sleep(for: updateDelays.removeFirst())
        }
        events.append(Event(kind: .update, state: state))
    }

    func end(sessionID: UUID, state: SessionActivityState?, dismissal: Date) async {
        events.append(Event(kind: .end, state: state, dismissal: dismissal))
        existing.removeAll { $0 == sessionID }
    }
}
