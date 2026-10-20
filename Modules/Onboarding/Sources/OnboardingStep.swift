import Foundation
import SwiftUI

/// One stage of an onboarding flow. Apps describe the flow as an ordered array of steps and hand it
/// to `OnboardingView(steps:onFinish:)` or `.onboardingGate(steps:version:record:)`.
///
/// Step kinds follow Apple's onboarding guidance: a welcome sheet that names the app's value in a
/// few rows, an optional question whose answer changes the product, optional tour pages, a
/// pre-permission primer with exactly one Continue button, and a custom slot for anything else
/// (sign-in lives in its own module and plugs in here). The flow is skippable by default; a step
/// opts out with `allowsSkip: false`, which permission primers do.
public struct OnboardingStep: Identifiable, Sendable {
    public enum Kind: Sendable {
        case welcome(WelcomeContent)
        case page(OnboardingPage)
        case choice(OnboardingChoice)
        case permission(PermissionPrimer)
        case custom(CustomStepContent)
    }

    public var id: String
    public var kind: Kind
    /// Whether the flow-wide Skip button shows while this step is on screen. Never shown on the last step.
    public var allowsSkip: Bool
    /// Label of the Continue button on this step; `nil` uses the flow's continue or finish title.
    public var continueTitle: String?

    public init(id: String, kind: Kind, allowsSkip: Bool = true, continueTitle: String? = nil) {
        self.id = id
        self.kind = kind
        self.allowsSkip = allowsSkip
        self.continueTitle = continueTitle
    }

    /// The Stocks/Journal-style welcome sheet: icon, title, feature rows, one Continue.
    public static func welcome(_ content: WelcomeContent, id: String = "welcome", allowsSkip: Bool = true,
                               continueTitle: String? = nil) -> OnboardingStep {
        OnboardingStep(id: id, kind: .welcome(content), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// A classic tour card; identity comes from the page.
    public static func page(_ page: OnboardingPage, allowsSkip: Bool = true,
                            continueTitle: String? = nil) -> OnboardingStep {
        OnboardingStep(id: page.id, kind: .page(page), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// One question, single or multiple select; identity comes from the choice.
    public static func choice(_ choice: OnboardingChoice, allowsSkip: Bool = true,
                              continueTitle: String? = nil) -> OnboardingStep {
        OnboardingStep(id: choice.id, kind: .choice(choice), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// A pre-permission screen. Skip is off by default: the HIG asks for exactly one button here,
    /// and the system alert that follows is where people decline. The button reads
    /// `primer.continueTitle` unless the step sets `continueTitle`.
    public static func permission(_ primer: PermissionPrimer, allowsSkip: Bool = false,
                                  continueTitle: String? = nil) -> OnboardingStep {
        OnboardingStep(id: primer.id, kind: .permission(primer), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// Any SwiftUI view; the flow supplies the Skip and Continue controls around it.
    public static func custom(id: String, allowsSkip: Bool = true, continueTitle: String? = nil,
                              @ViewBuilder content: @escaping @MainActor @Sendable () -> some View) -> OnboardingStep {
        OnboardingStep(id: id, kind: .custom(CustomStepContent(content)), allowsSkip: allowsSkip,
                       continueTitle: continueTitle)
    }

    /// Wraps pages as steps, for the `pages:` initializers that predate steps.
    public static func pages(_ pages: [OnboardingPage]) -> [OnboardingStep] {
        pages.map { OnboardingStep.page($0) }
    }

    /// Skip shows when the step allows it and another step follows.
    public func showsSkip(isLast: Bool) -> Bool {
        allowsSkip && !isLast
    }

    /// The template's flow: one of each shipped step kind, so an app sees them once and keeps what it
    /// needs. The choice step asks what the user will build (multiple select; option identifiers are
    /// the titles) and hands each answer to `onChoice`. The permission primer asks for notifications;
    /// `PermissionOverride` lets UI tests and previews replace the system prompt with a fake outcome
    /// through a launch argument.
    public static func template(onChoice: @escaping @MainActor @Sendable ([String]) -> Void = { _ in }) -> [OnboardingStep] {
        [
            .welcome(WelcomeContent(
                icon: .system("sparkles"),
                title: "Welcome to Starter App",
                features: [
                    WelcomeFeature(systemImage: "iphone.gen3", title: "Built for your phone",
                                   detail: "Every build is tested on GitHub Actions before it reaches you."),
                    WelcomeFeature(systemImage: "square.stack.3d.up", title: "Made of modules",
                                   detail: "Theme, onboarding and settings are packages you keep or drop."),
                    WelcomeFeature(systemImage: "slider.horizontal.3", title: "Make it yours",
                                   detail: "Replace these steps with your own in one array of OnboardingStep values."),
                ])),
            .choice(OnboardingChoice(
                id: "build",
                title: "What will you build?",
                message: "The app adapts to the answer. Ask only what changes what people see.",
                options: [
                    .init(title: "A tool for myself", systemImage: "hammer"),
                    .init(title: "Something for friends", systemImage: "person.2"),
                    .init(title: "A product to sell", systemImage: "storefront"),
                ],
                mode: .multiple,
                onAnswer: onChoice)),
            .page(OnboardingPage(id: "tour", systemImage: "hand.draw",
                                 title: "Swipe or tap",
                                 message: "Pages like this one are the classic tour card. Keep as many or as few as the app needs.")),
            .permission(PermissionPrimer(
                id: "notifications",
                systemImage: "bell.badge",
                title: "Stay in the loop",
                message: "Starter App can tell you when a new build is ready to try. You decide on the next screen.",
                requester: PermissionOverride.resolve(real: NotificationPermission()))),
        ]
    }

    /// The template's flow with no one listening to the choice step's answer.
    public static let templateDefaults: [OnboardingStep] = template()
}
