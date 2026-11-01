import Foundation
#if os(iOS)
import ActivityKit
#endif

/// What stays fixed for one session's activity: the plan's title, the session's identity and the
/// link the activity opens. The dynamic part is `SessionActivityState`.
public struct SessionActivityAttributes: Codable, Hashable, Sendable {
    public var planTitle: String
    public var sessionID: UUID
    /// Opened when a person taps the activity, such as `starterapp://timer`; nil opens the app.
    public var link: URL?

    public init(planTitle: String, sessionID: UUID, link: URL?) {
        self.planTitle = planTitle
        self.sessionID = sessionID
        self.link = link
    }
}

#if os(iOS)
extension SessionActivityAttributes: ActivityAttributes {
    public typealias ContentState = SessionActivityState
}
#endif
