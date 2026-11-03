import Foundation
import Observation
import SessionTimer

/// Keeps one Live Activity in step with a session: starts it when the session starts, updates it
/// on every change the app sees, ends it when the session finishes or resets, and removes it when
/// the person turns the setting off.
///
/// Own one per app, not per screen: an App Intent from the activity runs in the app's process
/// while no screen exists. Call `endOthers(than:)` and `sessionChanged` on launch so an activity
/// from an earlier process is found and ended or updated instead of leaking.
///
/// Every ActivityKit call runs through one queue, in the order the session changed, and decides
/// what to do when it runs, not when it was queued: whether the session has an activity depends
/// on the calls queued before it. A setting turned off and on again, or a session ended and
/// started again, would otherwise read a stale answer (an update to an activity about to end, or a
/// start that the queued end then removes).
@MainActor @Observable
public final class SessionActivityController {
    /// How long a finished session stays on the Lock Screen; the HIG suggests 15 to 30 minutes.
    public static let dismissalDelay: Duration = .seconds(15 * 60)

    private let host: any SessionActivityHost
    private let isEnabled: () -> Bool
    private let now: () -> Date
    @ObservationIgnored private var pending: Task<Void, Never>?

    /// The number of this app's activities, refreshed after each ActivityKit call, for a UI-test readout.
    public private(set) var activityCount = 0

    /// - Parameters:
    ///   - host: ActivityKit, or a recorder in tests.
    ///   - isEnabled: The person's setting; `SessionActivityPreferences` by default.
    ///   - now: The wall clock; tests pass a fixed one.
    public init(host: any SessionActivityHost, isEnabled: @escaping () -> Bool, now: @escaping () -> Date = { .now }) {
        self.host = host
        self.isEnabled = isEnabled
        self.now = now
        activityCount = host.activityCount
    }

    /// The session changed: start, update or end its activity accordingly.
    public func sessionChanged(_ snapshot: SessionSnapshot, plan: SessionPlan, attributes: SessionActivityAttributes) {
        let date = now()
        guard let state = SessionActivityState(snapshot, plan: plan, now: date), isEnabled(), host.areActivitiesEnabled else {
            end(sessionID: attributes.sessionID, state: nil)
            return
        }
        switch state.status {
        case .running, .paused:
            enqueue { [host] in
                if host.hasActivity(for: attributes.sessionID) {
                    await host.update(sessionID: attributes.sessionID, state: state)
                } else {
                    // One session at a time: a finished session's card, or an activity left by a
                    // launch the app never returned from, would otherwise sit beside the new one.
                    await Self.end(host, allBut: attributes.sessionID, at: date)
                    // Refused starts (in the background, too many activities) leave the timer as it is.
                    try? host.start(attributes, state: state)
                }
            }
        case .finished:
            end(sessionID: attributes.sessionID, state: state)
        }
    }

    /// The person turned the setting off: remove the session's activity now. For the setting turned
    /// on, re-send the current session with `sessionChanged`; it starts the activity, since the
    /// setting is read on every change.
    public func settingChanged(sessionID: UUID) {
        if isEnabled() == false { end(sessionID: sessionID, state: nil) }
    }

    /// Remove every activity but `sessionID`'s at once: on launch, with the stored session's
    /// identifier (nil when there is no session), so an activity from an earlier process whose
    /// session is gone doesn't stay until the system's limit.
    public func endOthers(than sessionID: UUID?) {
        let date = now()
        enqueue { [host] in await Self.end(host, allBut: sessionID, at: date) }
    }

    /// End the activity for `sessionID`, if there is one, keeping it on the Lock Screen for a
    /// while when it has a final state to show.
    public func end(sessionID: UUID, state: SessionActivityState?) {
        let dismissal = state == nil ? now() : now().addingTimeInterval(Self.dismissalSeconds)
        enqueue { [host] in
            guard host.hasActivity(for: sessionID) else { return }
            await host.end(sessionID: sessionID, state: state, dismissal: dismissal)
        }
    }

    /// Wait for the queued ActivityKit calls to finish; tests call it before checking the host.
    public func drain() async {
        await pending?.value
    }

    /// Calls run in order, one at a time, so a quick pause and resume can't arrive swapped.
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = pending
        pending = Task { [host] in
            await previous?.value
            await operation()
            activityCount = host.activityCount
        }
    }

    private static func end(_ host: any SessionActivityHost, allBut sessionID: UUID?, at date: Date) async {
        for other in host.sessionIDs where other != sessionID {
            await host.end(sessionID: other, state: nil, dismissal: date)
        }
    }

    private static var dismissalSeconds: TimeInterval {
        Double(dismissalDelay.components.seconds)
    }
}
