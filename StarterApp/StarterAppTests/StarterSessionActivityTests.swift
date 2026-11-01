#if canImport(SessionTimer) && canImport(SessionActivity)
import Foundation
import SessionActivity
import SessionTimer
import Testing
@testable import StarterApp

/// The activity's button, performed against the stored record and a fake ActivityKit.
@MainActor
struct StarterSessionActivityTests {
    private let suiteName = "StarterSessionActivityTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let host = FakeActivityHost()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    @Test func togglePausesAndResumesTheStoredSessionAndUpdatesItsActivity() async {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let id = UUID()
        host.existing.insert(id)
        SessionRecord(id: id, plan: .intervals, times: PlanTimes(work: 20, rest: 10, rounds: 3),
                      clock: SessionClockState(banked: .seconds(4), runningSince: .now, hasStarted: true)).save(to: defaults)
        let activity = StarterSessionActivity(defaults: defaults, host: host)

        await activity.toggle(id)
        let paused = SessionRecord.load(from: defaults)
        #expect(paused?.clock.isRunning == false)
        #expect(host.updates.last?.status == .paused)
        #expect(host.updates.last?.pausedRemaining.map { $0 <= .seconds(16) && $0 > .seconds(14) } == true)

        await activity.toggle(id)
        #expect(SessionRecord.load(from: defaults)?.clock.isRunning == true)
        #expect(host.updates.last?.status == .running)
        #expect(host.updates.count == 2)
    }

    @Test func toggleIgnoresAnUnknownSession() async {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let activity = StarterSessionActivity(defaults: defaults, host: host)
        await activity.toggle(UUID())
        #expect(host.updates.isEmpty)
        #expect(SessionRecord.load(from: defaults) == nil)
    }

    @Test func attributesCarryThePlanAndTheTimerLink() {
        let id = UUID()
        let attributes = StarterSessionActivity.attributes(for: .focus, sessionID: id)
        #expect(attributes.planTitle == "Focus")
        #expect(attributes.sessionID == id)
        #expect(attributes.link?.host() == "timer")
    }
}

@MainActor
private final class FakeActivityHost: SessionActivityHost {
    var areActivitiesEnabled = true
    var existing: Set<UUID> = []
    var updates: [SessionActivityState] = []

    var activityCount: Int { existing.count }
    func hasActivity(for sessionID: UUID) -> Bool { existing.contains(sessionID) }
    func start(_ attributes: SessionActivityAttributes, state: SessionActivityState) throws {
        existing.insert(attributes.sessionID)
        updates.append(state)
    }
    func update(sessionID: UUID, state: SessionActivityState) async { updates.append(state) }
    func end(sessionID: UUID, state: SessionActivityState?, dismissal: Date) async { existing.remove(sessionID) }
}
#endif
