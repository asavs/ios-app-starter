import Foundation

/// Result of a permission request. The flow continues on every case; apps read the system's
/// authorization state later when they need it.
public enum PermissionOutcome: String, Sendable, Equatable, CaseIterable {
    case granted
    case denied
    /// The prompt could not be shown, for example because the feature is restricted on this device.
    case unavailable
}
