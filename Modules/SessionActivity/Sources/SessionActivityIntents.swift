import Foundation

/// What the activity's intents do, installed by the app at launch (in the `App`'s `init`, which
/// also runs when the system launches the app in the background to perform an intent).
@MainActor
public enum SessionActivityIntents {
    /// Pause a running session or resume a paused one, then update its activity. The app loads
    /// the session's stored state, changes it, saves it and publishes the new content.
    public static var toggle: (@MainActor (UUID) async -> Void)?
}
