#if canImport(SessionTimer)
import Foundation
import SessionTimer
import SwiftUI
import Testing
@testable import StarterApp
#if canImport(Cues)
import Cues
#endif

/// The Timer tab's logic against an isolated defaults suite and a controlled clock.
@MainActor
struct TimerScreenModelTests {
    private final class TestClock {
        var now = ContinuousClock.now
    }

    private let suiteName = "TimerScreenModelTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let clock = TestClock()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    private func makeModel(plan: TimerPlan = .intervals) -> TimerScreenModel {
        TimerScreenModel(defaults: defaults, plan: plan) { [clock] in clock.now }
    }

    @Test func startsWithEachPlansDefaults() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        #expect(model.times == PlanTimes(work: 20, rest: 10, rounds: 3))
        #expect(model.timer.plan.phases.count == 5, "Three rounds with rests between")
        model.plan = .focus
        #expect(model.times == PlanTimes(work: 1500, rest: 300, rounds: 4))
        #expect(model.timer.snapshot.phaseRemaining == .seconds(1500))
    }

    @Test func editedTimesAreStoredPerPlanAndLoaded() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        model.times.workDuration = .seconds(30)
        model.times.rounds = 4
        #expect(defaults.string(forKey: "timer.intervals") == "30,10,4")
        #expect(model.timer.snapshot.phaseRemaining == .seconds(30))
        #expect(model.timer.plan.phases.count == 7)
        model.plan = .focus
        model.plan = .intervals
        #expect(model.times == PlanTimes(work: 30, rest: 10, rounds: 4), "Switching back restores the edit")
        #expect(makeModel().times == PlanTimes(work: 30, rest: 10, rounds: 4), "A new model reads the stored times")
    }

    @Test(arguments: ["", "garbage", "1,2", "a,b,c"])
    func unreadableStoredTimesUseTheDefaults(_ stored: String) {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(stored, forKey: "timer.intervals")
        #expect(makeModel().times == TimerPlan.intervals.defaultTimes)
    }

    @Test func storedTimesAreKeptInRange() {
        #expect(PlanTimes(rawValue: "0,-5,99") == PlanTimes(work: 1, rest: 1, rounds: 20))
        var times = PlanTimes(work: 20, rest: 10, rounds: 3)
        times.rounds = 0
        #expect(times.rounds == 1)
    }

    @Test func thePrimaryButtonStartsPausesResumesAndStartsAgain() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        #expect(model.primaryTitle.key == "Start")
        model.primaryAction()
        #expect(model.timer.snapshot.status == .running)
        #expect(model.primaryTitle.key == "Pause")
        model.primaryAction()
        #expect(model.timer.snapshot.status == .paused)
        #expect(model.primaryTitle.key == "Resume")
        model.primaryAction()
        clock.now += .seconds(3600)
        model.skip() // Reads the clock: the session is over.
        #expect(model.timer.snapshot.status == .finished)
        #expect(model.primaryTitle.key == "Start again")
        model.primaryAction()
        #expect(model.timer.snapshot.status == .running)
        #expect(model.timer.snapshot.elapsed == .zero, "Starting again begins at the start")
    }

    @Test func thePlanCanChangeOnlyWhenNoSessionIsUnderway() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        #expect(model.canChangePlan)
        model.primaryAction()
        #expect(model.canChangePlan == false)
        model.primaryAction()
        #expect(model.canChangePlan == false, "Paused is still underway")
        model.reset()
        #expect(model.canChangePlan)
    }

#if canImport(Cues)
    @Test func sessionChangesPlayTheirCues() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        var played: [Cue] = []
        model.play = { played.append($0) }
        var previous = model.timer.snapshot
        func step(_ change: () -> Void) {
            change()
            model.sessionChanged(from: previous, to: model.timer.snapshot)
            previous = model.timer.snapshot
        }
        step(model.primaryAction) // Start.
        step { clock.now += .seconds(21) ; model.timer.pause() } // Into the rest, then paused: no cue for the pause.
        step(model.primaryAction) // Resume.
        step { clock.now += .seconds(9); model.skip() }
        step { clock.now += .seconds(3600); model.skip() } // Finish.
        #expect(played == [.start, .start, .phaseChange, .finished])
    }

    @Test func hapticsFollowTheSettingAndTheTransition() {
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = makeModel()
        let ready = model.timer.snapshot
        model.primaryAction()
        let running = model.timer.snapshot
        #expect(model.haptic(from: ready, to: running) == .start)
        #expect(model.haptic(from: running, to: running) == nil, "No change, no tap")
        model.primaryAction()
        #expect(model.haptic(from: running, to: model.timer.snapshot) == nil, "Pausing doesn't tap")
        defaults.set(false, forKey: CuePreferences.hapticsKey)
        #expect(model.haptic(from: ready, to: running) == nil, "Haptics off in Settings")
    }
#endif
}
#endif
