import Foundation

/// One screen of an onboarding flow: a symbol, a title and a short message.
///
/// Apps describe their flow as an array of pages and hand it to `OnboardingView` or the
/// `onboardingGate(pages:version:record:)` modifier. The page carries content only; layout and
/// styling come from the Theme module.
public struct OnboardingPage: Identifiable, Equatable, Hashable, Sendable {
    public var id: String
    /// SF Symbol name shown above the title.
    public var systemImage: String
    public var title: String
    public var message: String

    /// - Parameter id: Stable identity for the pager; defaults to the title.
    public init(id: String? = nil, systemImage: String, title: String, message: String) {
        self.id = id ?? title
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    /// Three pages that introduce an app built from the template; replace them with the app's own.
    public static let templateDefaults: [OnboardingPage] = [
        OnboardingPage(systemImage: "sparkles", title: "Welcome",
                       message: "A short tour of what this app does, one screen at a time."),
        OnboardingPage(systemImage: "iphone.gen3", title: "Built for your phone",
                       message: "Everything here was built and tested on GitHub Actions before it reached you."),
        OnboardingPage(systemImage: "slider.horizontal.3", title: "Make it yours",
                       message: "Replace these pages with your own in a single array of OnboardingPage values."),
    ]
}
