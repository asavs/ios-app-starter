import Foundation
import Testing
@testable import SessionTimer

struct SessionClockTests {
    private let t0 = ContinuousClock.now
    // 20 s work, 10 s rest, three rounds: work, rest, work, rest, work = 80 s.
    private let plan = SessionPlan.intervals(
        work: SessionPhase(kind: "work", title: "Work", duration: .seconds(20)),
        rest: SessionPhase(kind: "rest", title: "Rest", duration: .seconds(10)),
        rounds: 3)

    @Test func intervalsEndOnWork() {
        #expect(plan.phases.map(\.kind) == ["work", "rest", "work", "rest", "work"])
        #expect(plan.totalDuration == .seconds(80))
        let single = SessionPlan.intervals(work: plan.phases[0], rest: nil, rounds: 2)
        #expect(single.phases.map(\.kind) == ["work", "work"])
    }

    @Test func startsReady() {
        let snapshot = SessionClock(plan: plan).snapshot(at: t0 + .seconds(30))
        #expect(snapshot.status == .ready)
        #expect(snapshot.phaseIndex == 0)
        #expect(snapshot.phaseRemaining == .seconds(20))
        #expect(snapshot.phaseFractionRemaining == 1)
    }

    @Test func derivesThePhaseFromElapsedTime() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        let snapshot = clock.snapshot(at: t0 + .seconds(25))
        #expect(snapshot.status == .running)
        #expect(snapshot.phaseIndex == 1)
        #expect(snapshot.phaseRemaining == .seconds(5))
        #expect(snapshot.phaseFractionRemaining == 0.5)
        #expect(snapshot.remaining == .seconds(55))
    }

    @Test func aBoundaryBelongsToTheNextPhase() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        let snapshot = clock.snapshot(at: t0 + .seconds(20))
        #expect(snapshot.phaseIndex == 1)
        #expect(snapshot.phaseRemaining == .seconds(10))
    }

    @Test func aLateSnapshotCrossesSeveralPhases() {
        // The app was in the background for most of the session; nothing is lost.
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        let snapshot = clock.snapshot(at: t0 + .seconds(65))
        #expect(snapshot.phaseIndex == 4)
        #expect(snapshot.phaseRemaining == .seconds(15))
    }

    @Test func pausesExcludeTheirTime() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        clock.pause(at: t0 + .seconds(5))
        #expect(clock.snapshot(at: t0 + .seconds(500)).status == .paused)
        #expect(clock.snapshot(at: t0 + .seconds(500)).elapsed == .seconds(5))
        clock.start(at: t0 + .seconds(100))
        let snapshot = clock.snapshot(at: t0 + .seconds(110))
        #expect(snapshot.status == .running)
        #expect(snapshot.elapsed == .seconds(15))
    }

    @Test func repeatedCallsAreHarmless() {
        var clock = SessionClock(plan: plan)
        clock.pause(at: t0)
        clock.start(at: t0)
        clock.start(at: t0 + .seconds(10)) // Already running: keeps the first start.
        clock.pause(at: t0 + .seconds(12))
        clock.pause(at: t0 + .seconds(40))
        #expect(clock.snapshot(at: t0 + .seconds(50)).elapsed == .seconds(12))
    }

    @Test func finishesOnceAndStaysFinished() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        let done = clock.snapshot(at: t0 + .seconds(80))
        #expect(done.status == .finished)
        #expect(done.phaseIndex == 4)
        #expect(done.remaining == .zero)
        #expect(done.phaseFractionRemaining == 0)
        #expect(clock.snapshot(at: t0 + .seconds(9000)) == done)
        clock.pause(at: t0 + .seconds(90))
        clock.start(at: t0 + .seconds(95))
        #expect(clock.snapshot(at: t0 + .seconds(100)).status == .finished)
    }

    @Test func skipJumpsToTheNextPhaseAndKeepsRunning() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        clock.skipToNextPhase(at: t0 + .seconds(3))
        #expect(clock.snapshot(at: t0 + .seconds(3)).phaseIndex == 1)
        #expect(clock.snapshot(at: t0 + .seconds(8)).phaseRemaining == .seconds(5))
        #expect(clock.snapshot(at: t0 + .seconds(8)).status == .running)
    }

    @Test func skipWhilePausedStaysPaused() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        clock.pause(at: t0 + .seconds(3))
        clock.skipToNextPhase(at: t0 + .seconds(50))
        let snapshot = clock.snapshot(at: t0 + .seconds(60))
        #expect(snapshot.status == .paused)
        #expect(snapshot.phaseIndex == 1)
        #expect(snapshot.phaseRemaining == .seconds(10))
    }

    @Test func skippingTheLastPhaseFinishes() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        for second in 1...5 { clock.skipToNextPhase(at: t0 + .seconds(second)) }
        #expect(clock.snapshot(at: t0 + .seconds(6)).status == .finished)
        clock.skipToNextPhase(at: t0 + .seconds(7))
        #expect(clock.snapshot(at: t0 + .seconds(7)).status == .finished)
    }

    @Test func resetReturnsToReady() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        clock.reset()
        let snapshot = clock.snapshot(at: t0 + .seconds(30))
        #expect(snapshot.status == .ready)
        #expect(snapshot.elapsed == .zero)
    }

    @Test func anEarlierInstantCountsAsNoTime() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0 + .seconds(10))
        #expect(clock.snapshot(at: t0).elapsed == .zero)
    }

    @Test func pausingTheMomentItStartsIsPaused() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        clock.pause(at: t0)
        #expect(clock.snapshot(at: t0 + .seconds(5)).status == .paused)
        clock.reset()
        #expect(clock.snapshot(at: t0 + .seconds(5)).status == .ready)
    }
}
