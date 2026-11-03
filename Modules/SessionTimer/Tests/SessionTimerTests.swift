import Foundation
import Testing
@testable import SessionTimer

/// The driver against a controlled clock: `now` is whatever the test sets, so nothing waits.
@MainActor
struct SessionTimerTests {
    private final class TestClock {
        var now = ContinuousClock.now
    }

    private let clock = TestClock()
    private let plan = SessionPlan(phases: [
        SessionPhase(kind: "work", title: "Work", duration: .seconds(20)),
        SessionPhase(kind: "rest", title: "Rest", duration: .seconds(10)),
    ])

    private func makeTimer() -> SessionTimer {
        SessionTimer(plan: plan, refreshInterval: .seconds(3600)) { [clock] in clock.now }
    }

    @Test func loadingAStoredStateContinuesTheSession() {
        let timer = makeTimer()
        timer.start()
        clock.now += .seconds(12)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let state = timer.state(date: date)
        #expect(state.isRunning)

        let other = makeTimer()
        other.load(plan, state: state, date: date.addingTimeInterval(10))
        #expect(other.snapshot.status == .running)
        #expect(other.snapshot.phaseIndex == 1)
        #expect(other.snapshot.phaseRemaining == .seconds(8))
        #expect(other.isRefreshing)
    }

    @Test func refreshReadsTheClock() {
        let timer = makeTimer()
        timer.start()
        clock.now += .seconds(25)
        timer.refresh()
        #expect(timer.snapshot.phaseIndex == 1)
        #expect(timer.snapshot.phaseRemaining == .seconds(5))
    }

    @Test func everyChangeReachesTheObserverOnceWithBothSnapshots() {
        let timer = makeTimer()
        var changes: [(SessionSnapshot.Status, Int)] = []
        timer.onChange = { old, new in
            #expect(old != new, "Only a change is reported")
            changes.append((new.status, new.phaseIndex))
        }
        timer.refresh()
        #expect(changes.isEmpty, "A refresh that changes nothing reports nothing")
        timer.start()
        clock.now += .seconds(21) // Into the rest phase.
        timer.refresh()
        timer.pause()
        timer.pause() // Already paused: no change.
        timer.start()
        timer.reset()
        #expect(changes.map(\.0) == [.running, .running, .paused, .running, .ready])
        #expect(changes.map(\.1) == [0, 1, 1, 1, 0])
        timer.onChange = nil
        timer.start()
        #expect(changes.count == 5, "Nothing listens any more")
    }

    @Test func refreshesOnlyWhileRunning() {
        let timer = makeTimer()
        #expect(timer.isRefreshing == false)
        timer.start()
        #expect(timer.isRefreshing)
        timer.pause()
        #expect(timer.isRefreshing == false, "A paused session has nothing to refresh")
        timer.start()
        clock.now += .seconds(60)
        timer.refresh()
        #expect(timer.snapshot.status == .finished)
        #expect(timer.isRefreshing == false, "A finished session stops refreshing")
    }

    @Test func resetAndLoadingAPlanStopRefreshing() {
        let timer = makeTimer()
        timer.start()
        timer.reset()
        #expect(timer.isRefreshing == false, "Nothing runs for a session at the start")
        timer.start()
        timer.load(plan)
        #expect(timer.isRefreshing == false, "A new plan starts at the start")
        timer.load(plan, state: SessionClockState(banked: .seconds(5), runningSince: nil, hasStarted: true))
        #expect(timer.isRefreshing == false, "A stored paused session has nothing to refresh")
    }

    @Test func pauseFreezesTheSnapshot() {
        let timer = makeTimer()
        timer.start()
        clock.now += .seconds(3)
        timer.pause()
        clock.now += .seconds(100)
        timer.refresh()
        #expect(timer.snapshot.status == .paused)
        #expect(timer.snapshot.elapsed == .seconds(3))
    }

    @Test func loadingAPlanResets() {
        let timer = makeTimer()
        timer.start()
        timer.skipToNextPhase()
        timer.load(SessionPlan(phases: [plan.phases[1]]))
        #expect(timer.snapshot.status == .ready)
        #expect(timer.plan.phases.count == 1)
    }

    @Test func skippingToTheEndFinishesAndResetReturnsToReady() {
        let timer = makeTimer()
        timer.start()
        timer.skipToNextPhase()
        timer.skipToNextPhase()
        #expect(timer.snapshot.status == .finished)
        timer.reset()
        #expect(timer.snapshot.status == .ready)
    }
}
