import Foundation

/// What an app tells people about their data, shown by `PrivacyNoticeView`.
///
/// App Review Guideline 5.1.1(i) requires a link to the privacy policy "within the app in an easily
/// accessible manner"; `policyURL` is that link. The sentences are the app's own, looked up in its
/// string catalog when written as literals.
public struct PrivacyNotice: Equatable, Sendable {
    /// One or two sentences: where data lives and whether the app works offline.
    public var summary: LocalizedStringResource
    /// What the app stores on the device, one item per row.
    public var stored: [LocalizedStringResource]
    /// What leaves the device and where it goes. Empty means nothing does, and the screen says so.
    public var shared: [LocalizedStringResource]
    /// How people delete their data, such as pointing at `ResetLocalDataButton`.
    public var deletion: LocalizedStringResource
    /// The published privacy policy. Nil hides the row; App Store submission needs one.
    public var policyURL: URL?

    public init(summary: LocalizedStringResource, stored: [LocalizedStringResource] = [],
                shared: [LocalizedStringResource] = [], deletion: LocalizedStringResource, policyURL: URL? = nil) {
        self.summary = summary
        self.stored = stored
        self.shared = shared
        self.deletion = deletion
        self.policyURL = policyURL
    }
}
