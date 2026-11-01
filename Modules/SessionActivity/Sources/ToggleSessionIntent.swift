#if os(iOS)
import AppIntents
import Foundation

/// The activity's one button: pause a running session or resume a paused one.
///
/// A `LiveActivityIntent` runs in the app's process, which the system launches in the background
/// if needed, so the app installs what to do in `SessionActivityIntents.toggle` at launch. The
/// widget extension only shows the button; it never performs the intent.
public struct ToggleSessionIntent: LiveActivityIntent {
    public static let title = LocalizedStringResource("Pause or Resume", bundle: .module)
    public static let isDiscoverable = false

    @Parameter(title: "Session")
    public var sessionID: String

    public init() {
        sessionID = ""
    }

    public init(sessionID: UUID) {
        self.sessionID = sessionID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: sessionID) {
            await SessionActivityIntents.toggle?(id)
        }
        return .result()
    }
}
#endif
