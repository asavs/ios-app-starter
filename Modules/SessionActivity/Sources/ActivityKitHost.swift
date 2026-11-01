#if os(iOS)
import ActivityKit
import Foundation

/// `SessionActivityHost` on ActivityKit. Activities are looked up by their session identifier in
/// `Activity.activities`, so one found from an earlier launch is updated or ended, never leaked.
///
/// `Activity` isn't `Sendable`, so each asynchronous call looks its activity up in a nonisolated
/// function and uses it there, instead of carrying it across from the main actor.
@MainActor
public final class ActivityKitHost: SessionActivityHost {
    public init() {}

    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Activities still showing live content; an ended one waiting to be dismissed doesn't count.
    public var activityCount: Int {
        Activity<SessionActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }.count
    }

    public func hasActivity(for sessionID: UUID) -> Bool {
        Self.activity(for: sessionID) != nil
    }

    public func start(_ attributes: SessionActivityAttributes, state: SessionActivityState) throws {
        _ = try Activity.request(attributes: attributes,
                                 content: ActivityContent(state: state, staleDate: state.staleDate),
                                 pushType: nil)
    }

    public func update(sessionID: UUID, state: SessionActivityState) async {
        await Self.update(sessionID: sessionID, state: state)
    }

    public func end(sessionID: UUID, state: SessionActivityState?, dismissal: Date) async {
        await Self.end(sessionID: sessionID, state: state, dismissal: dismissal)
    }

    private nonisolated static func update(sessionID: UUID, state: SessionActivityState) async {
        guard let activity = activity(for: sessionID) else { return }
        await activity.update(ActivityContent(state: state, staleDate: state.staleDate))
    }

    private nonisolated static func end(sessionID: UUID, state: SessionActivityState?, dismissal: Date) async {
        guard let activity = activity(for: sessionID) else { return }
        let content = state.map { ActivityContent(state: $0, staleDate: nil) }
        await activity.end(content, dismissalPolicy: state == nil ? .immediate : .after(dismissal))
    }

    private nonisolated static func activity(for sessionID: UUID) -> Activity<SessionActivityAttributes>? {
        Activity<SessionActivityAttributes>.activities.first { $0.attributes.sessionID == sessionID }
    }
}
#endif
