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
