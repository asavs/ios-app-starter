import Foundation

/// One screen of an onboarding flow: a symbol, a title and a short message.
///
/// Apps describe their flow as an array of pages and hand it to `OnboardingView` or the
/// `onboardingGate(pages:version:record:)` modifier. The page carries content only; layout and
/// styling come from the Theme module.
public struct OnboardingPage: Identifiable, Equatable, Hashable, Sendable {
    /// Stable identity for the pager and the page's accessibility identifier; never shown.
    public var id: String
    /// SF Symbol name shown above the title.
    public var systemImage: String
    public var title: LocalizedStringResource
    public var message: LocalizedStringResource

    /// Text parameters written as literals are looked up in the app's string catalog.
    public init(id: String, systemImage: String, title: LocalizedStringResource, message: LocalizedStringResource) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id) // Localized text is not Hashable; equal pages share an identifier.
    }

    /// Three pages that introduce an app built from the template; replace them with the app's own.
    public static let templateDefaults: [OnboardingPage] = [
        OnboardingPage(id: "welcome", systemImage: "sparkles",
                       title: LocalizedStringResource("Welcome", bundle: .module),
                       message: LocalizedStringResource("A short tour of what this app does, one screen at a time.", bundle: .module)),
        OnboardingPage(id: "phone", systemImage: "iphone.gen3",
                       title: LocalizedStringResource("Built for your phone", bundle: .module),
                       message: LocalizedStringResource("Everything here was built and tested on GitHub Actions before it reached you.", bundle: .module)),
        OnboardingPage(id: "yours", systemImage: "slider.horizontal.3",
                       title: LocalizedStringResource("Make it yours", bundle: .module),
                       message: LocalizedStringResource("Replace these pages with your own in a single array of OnboardingPage values.", bundle: .module)),
    ]
}
