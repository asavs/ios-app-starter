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
    public var continueTitle: LocalizedStringResource?

    public init(id: String, kind: Kind, allowsSkip: Bool = true, continueTitle: LocalizedStringResource? = nil) {
        self.id = id
        self.kind = kind
        self.allowsSkip = allowsSkip
        self.continueTitle = continueTitle
    }

    /// The Stocks/Journal-style welcome sheet: icon, title, feature rows, one Continue.
    public static func welcome(_ content: WelcomeContent, id: String = "welcome", allowsSkip: Bool = true,
                               continueTitle: LocalizedStringResource? = nil) -> OnboardingStep {
        OnboardingStep(id: id, kind: .welcome(content), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// A classic tour card; identity comes from the page.
    public static func page(_ page: OnboardingPage, allowsSkip: Bool = true,
                            continueTitle: LocalizedStringResource? = nil) -> OnboardingStep {
        OnboardingStep(id: page.id, kind: .page(page), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// One question, single or multiple select; identity comes from the choice.
    public static func choice(_ choice: OnboardingChoice, allowsSkip: Bool = true,
                              continueTitle: LocalizedStringResource? = nil) -> OnboardingStep {
        OnboardingStep(id: choice.id, kind: .choice(choice), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// A pre-permission screen. Skip is off by default: the HIG asks for exactly one button here,
    /// and the system alert that follows is where people decline. The button reads
    /// `primer.continueTitle` unless the step sets `continueTitle`.
    public static func permission(_ primer: PermissionPrimer, allowsSkip: Bool = false,
                                  continueTitle: LocalizedStringResource? = nil) -> OnboardingStep {
        OnboardingStep(id: primer.id, kind: .permission(primer), allowsSkip: allowsSkip, continueTitle: continueTitle)
    }

    /// Any SwiftUI view; the flow supplies the Skip and Continue controls around it.
    public static func custom(id: String, allowsSkip: Bool = true, continueTitle: LocalizedStringResource? = nil,
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
    /// needs. The choice step (`templateChoice`) asks what the user will build and hands each answer
    /// to `onChoice`. Its text comes from this module's string catalog. The permission primer asks for notifications;
    /// `PermissionOverride` lets UI tests and previews replace the system prompt with a fake outcome
    /// through a launch argument.
    public static func template(onChoice: @escaping @MainActor @Sendable ([String]) -> Void = { _ in }) -> [OnboardingStep] {
        [
            .welcome(WelcomeContent(
                icon: .system("sparkles"),
                title: LocalizedStringResource("Welcome to Starter App", bundle: .module),
                features: [
                    WelcomeFeature(id: "phone", systemImage: "iphone.gen3",
                                   title: LocalizedStringResource("Built for your phone", bundle: .module),
                                   detail: LocalizedStringResource("Native SwiftUI for iPhone and iPad, with dark mode, large text and VoiceOver.", bundle: .module)),
                    WelcomeFeature(id: "modules", systemImage: "square.stack.3d.up",
                                   title: LocalizedStringResource("Made of modules", bundle: .module),
                                   detail: LocalizedStringResource("Onboarding, theme and settings are modules you keep or delete.", bundle: .module)),
                    WelcomeFeature(id: "yours", systemImage: "slider.horizontal.3",
                                   title: LocalizedStringResource("Make it yours", bundle: .module),
                                   detail: LocalizedStringResource("Replace these steps with your own in one array of OnboardingStep values.", bundle: .module)),
                ])),
            .choice(templateChoice(onAnswer: onChoice)),
            .page(OnboardingPage(id: "tour", systemImage: "hand.draw",
                                 title: LocalizedStringResource("Swipe or tap", bundle: .module),
                                 message: LocalizedStringResource("Pages like this one are the classic tour card. Keep as many or as few as the app needs.", bundle: .module))),
            .permission(PermissionPrimer(
                id: "notifications",
                systemImage: "bell.badge",
                title: LocalizedStringResource("Stay in the loop", bundle: .module),
                message: LocalizedStringResource("Notifications let Starter App tell you when something changes. You decide on the next screen.", bundle: .module),
                requester: PermissionOverride.resolve(real: NotificationPermission()))),
        ]
    }

    /// The template's question: what the user will build, multiple select, with the option
    /// identifiers `tool`, `friends` and `product`.
    public static func templateChoice(onAnswer: @escaping @MainActor @Sendable ([String]) -> Void = { _ in }) -> OnboardingChoice {
        OnboardingChoice(
            id: "build",
            title: LocalizedStringResource("What will you build?", bundle: .module),
            message: LocalizedStringResource("The app adapts to the answer. Ask only what changes what people see.", bundle: .module),
            options: [
                .init(id: "tool", title: LocalizedStringResource("A tool for myself", bundle: .module), systemImage: "hammer"),
                .init(id: "friends", title: LocalizedStringResource("Something for friends", bundle: .module), systemImage: "person.2"),
                .init(id: "product", title: LocalizedStringResource("A product to sell", bundle: .module), systemImage: "storefront"),
            ],
            mode: .multiple,
            onAnswer: onAnswer)
    }

    /// The template's flow with no one listening to the choice step's answer.
    public static let templateDefaults: [OnboardingStep] = template()
}
