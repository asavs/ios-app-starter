import Foundation
import Testing
@testable import SessionTimer

struct SessionTransitionTests {
    private let t0 = ContinuousClock.now
    private let plan = SessionPlan.intervals(
        work: SessionPhase(kind: "work", title: "Work", duration: .seconds(20)),
        rest: SessionPhase(kind: "rest", title: "Rest", duration: .seconds(10)),
        rounds: 2)

    @Test func reportsPhaseStartsAndFinishingOnce() {
        var clock = SessionClock(plan: plan)
        let ready = clock.snapshot(at: t0)
        clock.start(at: t0)
        let started = clock.snapshot(at: t0)
        #expect(started.transition(from: ready) == .started)
        let working = clock.snapshot(at: t0 + .seconds(19))
        let resting = clock.snapshot(at: t0 + .seconds(21))
        #expect(working.transition(from: started) == nil)
        #expect(resting.transition(from: working) == .phaseStarted(index: 1))
        let done = clock.snapshot(at: t0 + .seconds(50))
        #expect(done.transition(from: resting) == .finished)
        #expect(clock.snapshot(at: t0 + .seconds(60)).transition(from: done) == nil)
    }

    @Test func pausesSkipsWhilePausedAndResetsAreQuiet() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        clock.pause(at: t0 + .seconds(1))
        let paused = clock.snapshot(at: t0 + .seconds(1))
        clock.skipToNextPhase(at: t0 + .seconds(2))
        #expect(clock.snapshot(at: t0 + .seconds(2)).transition(from: paused) == nil)
        let skipped = clock.snapshot(at: t0 + .seconds(2))
        clock.start(at: t0 + .seconds(2))
        #expect(clock.snapshot(at: t0 + .seconds(2)).transition(from: skipped) == .resumed)
        let resumed = clock.snapshot(at: t0 + .seconds(2))
        clock.reset()
        #expect(clock.snapshot(at: t0 + .seconds(3)).transition(from: resumed) == nil)
    }

    @Test func startingAgainAfterFinishingIsAStart() {
        var clock = SessionClock(plan: plan)
        clock.start(at: t0)
        let done = clock.snapshot(at: t0 + .seconds(60))
        clock.reset()
        clock.start(at: t0 + .seconds(61))
        #expect(clock.snapshot(at: t0 + .seconds(61)).transition(from: done) == .started)
    }
}
