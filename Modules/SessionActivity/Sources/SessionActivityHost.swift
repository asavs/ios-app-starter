import Foundation

/// What `SessionActivityController` needs from ActivityKit, so the controller is testable with a
/// recorder and compiles on the Mac host. `ActivityKitHost` is the real one.
@MainActor
public protocol SessionActivityHost: AnyObject {
    /// Whether the person allows this app's Live Activities (Settings > the app > Live Activities).
    var areActivitiesEnabled: Bool { get }
    /// Whether an activity for `sessionID` exists, started by this process or found from an
    /// earlier launch.
    func hasActivity(for sessionID: UUID) -> Bool
    /// The number of this app's activities, for tests and a UI-test readout.
    var activityCount: Int { get }
    /// Start an activity. Throws when the system refuses (disabled, too many, in the background).
    func start(_ attributes: SessionActivityAttributes, state: SessionActivityState) throws
    func update(sessionID: UUID, state: SessionActivityState) async
    /// End the activity with a final state, removing it after `dismissal` at the latest.
    func end(sessionID: UUID, state: SessionActivityState?, dismissal: Date) async
}
