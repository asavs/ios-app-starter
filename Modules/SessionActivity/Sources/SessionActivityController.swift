import Foundation
import Observation
import SessionTimer

/// Keeps one Live Activity in step with a session: starts it when the session starts, updates it
/// on every change the app sees, ends it when the session finishes or resets, and removes it when
/// the person turns the setting off.
///
/// Own one per app, not per screen: an App Intent from the activity runs in the app's process
/// while no screen exists. Call `reattach()` on launch so an activity from an earlier process is
/// found and ended or updated instead of leaking.
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
        guard let state = SessionActivityState(snapshot, plan: plan, now: date) else {
            end(sessionID: attributes.sessionID, state: nil)
            return
        }
        guard isEnabled(), host.areActivitiesEnabled else {
            end(sessionID: attributes.sessionID, state: nil)
            return
        }
        switch state.status {
        case .running, .paused:
            if host.hasActivity(for: attributes.sessionID) {
                enqueue { [host] in await host.update(sessionID: attributes.sessionID, state: state) }
            } else {
                // Refused starts (in the background, too many activities) leave the timer as it is.
                try? host.start(attributes, state: state)
                activityCount = host.activityCount
            }
        case .finished:
            end(sessionID: attributes.sessionID, state: state)
        }
    }

    /// The person turned the setting off: remove the session's activity now.
    public func settingChanged(sessionID: UUID) {
        if isEnabled() == false { end(sessionID: sessionID, state: nil) }
    }

    /// End the activity for `sessionID`, if there is one, keeping it on the Lock Screen for a
    /// while when it has a final state to show.
    public func end(sessionID: UUID, state: SessionActivityState?) {
        guard host.hasActivity(for: sessionID) else { return }
        let dismissal = state == nil ? now() : now().addingTimeInterval(Self.dismissalSeconds)
        enqueue { [host] in await host.end(sessionID: sessionID, state: state, dismissal: dismissal) }
    }

    /// Wait for the queued ActivityKit calls to finish; tests call it before checking the host.
    public func drain() async {
        await pending?.value
    }

    /// Updates run in order, one at a time, so a quick pause and resume can't arrive swapped.
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = pending
        pending = Task { [host] in
            await previous?.value
            await operation()
            activityCount = host.activityCount
        }
    }

    private static var dismissalSeconds: TimeInterval {
        Double(dismissalDelay.components.seconds)
    }
}
