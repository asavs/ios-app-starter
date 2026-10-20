import Foundation

/// Presents a system permission prompt, or resolves at once when the user already decided, and
/// reports the outcome. `NotificationPermission` is the shipped implementation; apps add their own
/// for location, camera and the like; `FakePermission` stands in for tests and previews.
public protocol PermissionRequesting: Sendable {
    func request() async -> PermissionOutcome
}
