import Foundation

/// Sample content for previews and tests.
public extension SessionActivityState {
    static var previewRunning: SessionActivityState {
        SessionActivityState(status: .running, phaseIndex: 1, phaseCount: 5, phaseTitle: "Rest", phaseKind: "rest",
                             phaseDuration: .seconds(10), phase: Date.now...Date.now.addingTimeInterval(8),
                             pausedRemaining: nil, sessionEnd: Date.now.addingTimeInterval(58))
    }

    static var previewPaused: SessionActivityState {
        SessionActivityState(status: .paused, phaseIndex: 2, phaseCount: 5, phaseTitle: "Work", phaseKind: "work",
                             phaseDuration: .seconds(20), phase: nil, pausedRemaining: .seconds(14),
                             sessionEnd: Date.now.addingTimeInterval(44))
    }

    static var previewFinished: SessionActivityState {
        SessionActivityState(status: .finished, phaseIndex: 4, phaseCount: 5, phaseTitle: "Work", phaseKind: "work",
                             phaseDuration: .seconds(20), phase: nil, pausedRemaining: nil, sessionEnd: .now)
    }
}

public extension SessionActivityAttributes {
    static var preview: SessionActivityAttributes {
        SessionActivityAttributes(planTitle: "Intervals", sessionID: UUID(), link: nil)
    }
}
