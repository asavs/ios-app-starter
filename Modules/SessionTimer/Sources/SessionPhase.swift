import Foundation

/// One timed step of a session, such as a hold, a rest or a focus block.
public struct SessionPhase: Sendable {
    /// A stable name the host uses to style or describe the phase, such as `"work"`. Never shown.
    public let kind: String
    public let title: LocalizedStringResource
    public let duration: Duration

    public init(kind: String, title: LocalizedStringResource, duration: Duration) {
        precondition(duration > .zero, "A phase needs a positive duration")
        self.kind = kind
        self.title = title
        self.duration = duration
    }
}
