import Foundation

/// Content of a pre-permission step: why the app wants the permission, shown before the system
/// alert. Per the HIG the screen has exactly one button, labelled Continue or Next, never Allow,
/// and no Cancel; tapping it runs `requester`, and the flow moves on whatever the outcome.
public struct PermissionPrimer: Identifiable, Sendable {
    public var id: String
    public var systemImage: String
    public var title: LocalizedStringResource
    public var message: LocalizedStringResource
    /// Small print under the message; `nil` hides it.
    public var footnote: LocalizedStringResource?
    /// Label of the single button. Keep it "Continue" or "Next".
    public var continueTitle: LocalizedStringResource
    public var requester: any PermissionRequesting

    /// Text parameters written as literals are looked up in the app's string catalog; the defaults
    /// come from this module's.
    public init(id: String, systemImage: String, title: LocalizedStringResource, message: LocalizedStringResource,
                footnote: LocalizedStringResource? = PermissionPrimer.defaultFootnote,
                continueTitle: LocalizedStringResource = PermissionPrimer.defaultContinueTitle,
                requester: any PermissionRequesting) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.footnote = footnote
        self.continueTitle = continueTitle
        self.requester = requester
    }

    /// "You can change this anytime in Settings.", from this module's string catalog.
    public static let defaultFootnote = LocalizedStringResource("You can change this anytime in Settings.", bundle: .module)
    /// "Continue", from this module's string catalog.
    public static let defaultContinueTitle = LocalizedStringResource("Continue", bundle: .module)

    /// The primer as a tour card, which is how `PermissionStepView` lays it out.
    public var page: OnboardingPage {
        OnboardingPage(id: id, systemImage: systemImage, title: title, message: message)
    }
}
