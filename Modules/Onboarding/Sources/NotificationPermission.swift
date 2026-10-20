import Foundation
import UserNotifications

/// Requests notification authorization from the system. No entitlement is needed for local
/// notifications; remote (push) notifications also need the capability in the app's manifest.
public struct NotificationPermission: PermissionRequesting {
    private let options: UInt

    public init(options: UNAuthorizationOptions = [.alert, .badge, .sound]) {
        self.options = options.rawValue
    }

    public func request() async -> PermissionOutcome {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: UNAuthorizationOptions(rawValue: options))
            return granted ? .granted : .denied
        } catch {
            return .unavailable
        }
    }
}
