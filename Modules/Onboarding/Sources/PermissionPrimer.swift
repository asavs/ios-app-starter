import Foundation

/// Content of a pre-permission step: why the app wants the permission, shown before the system
/// alert. Per the HIG the screen has exactly one button, labelled Continue or Next, never Allow,
/// and no Cancel; tapping it runs `requester`, and the flow moves on whatever the outcome.
public struct PermissionPrimer: Identifiable, Sendable {
    public var id: String
    public var systemImage: String
    public var title: String
    public var message: String
    /// Small print under the message; `nil` hides it.
    public var footnote: String?
    /// Label of the single button. Keep it "Continue" or "Next".
    public var continueTitle: String
    public var requester: any PermissionRequesting

    public init(id: String, systemImage: String, title: String, message: String,
                footnote: String? = "You can change this anytime in Settings.",
                continueTitle: String = "Continue", requester: any PermissionRequesting) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.footnote = footnote
        self.continueTitle = continueTitle
        self.requester = requester
    }

    /// The primer as a tour card, which is how `PermissionStepView` lays it out.
    public var page: OnboardingPage {
        OnboardingPage(id: id, systemImage: systemImage, title: title, message: message)
    }
}
