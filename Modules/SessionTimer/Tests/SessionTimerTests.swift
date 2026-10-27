import Foundation
import Testing
@testable import SessionTimer

@MainActor
struct SessionTimerTests {
    private let plan = SessionPlan(phases: [
        SessionPhase(kind: "work", title: "Work", duration: .milliseconds(300)),
        SessionPhase(kind: "rest", title: "Rest", duration: .seconds(60)),
    ])

    @Test func refreshesWhileRunning() async throws {
        let timer = SessionTimer(plan: plan, refreshInterval: .milliseconds(20))
        timer.start()
        #expect(timer.snapshot.status == .running)
        try await Task.sleep(for: .milliseconds(600))
        #expect(timer.snapshot.phaseIndex == 1)
        timer.pause()
    }

    @Test func pauseFreezesTheSnapshot() async throws {
        let timer = SessionTimer(plan: plan, refreshInterval: .milliseconds(20))
        timer.start()
        timer.pause()
        let paused = timer.snapshot
        try await Task.sleep(for: .milliseconds(100))
        #expect(timer.snapshot == paused)
        #expect(paused.status == .paused)
    }

    @Test func loadingAPlanResets() {
        let timer = SessionTimer(plan: plan)
        timer.start()
        timer.skipToNextPhase()
        timer.load(SessionPlan(phases: [plan.phases[1]]))
        #expect(timer.snapshot.status == .ready)
        #expect(timer.plan.phases.count == 1)
    }

    @Test func skippingToTheEndFinishes() {
        let timer = SessionTimer(plan: plan)
        timer.start()
        timer.skipToNextPhase()
        timer.skipToNextPhase()
        #expect(timer.snapshot.status == .finished)
        timer.reset()
        #expect(timer.snapshot.status == .ready)
    }
}
