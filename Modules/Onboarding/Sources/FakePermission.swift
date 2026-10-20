import Foundation

/// A requester that reports a fixed outcome without a system prompt, for UI tests and previews.
public struct FakePermission: PermissionRequesting {
    public var outcome: PermissionOutcome
    /// Optional pause before answering, so a preview shows the busy state.
    public var delay: Duration

    public init(outcome: PermissionOutcome = .granted, delay: Duration = .zero) {
        self.outcome = outcome
        self.delay = delay
    }

    public func request() async -> PermissionOutcome {
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return outcome
    }
}
