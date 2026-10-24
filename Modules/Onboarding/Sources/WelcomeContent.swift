import Foundation

/// Content of the welcome step: the app's icon or a symbol, a title, an optional line under it and
/// the feature rows that say what the app is for. Layout comes from `WelcomeStepView`.
public struct WelcomeContent: Sendable, Equatable, Hashable {
    public enum Icon: Sendable, Equatable, Hashable {
        /// An SF Symbol drawn in the accent color.
        case system(String)
        /// An image from the app's asset catalog, typically a copy of the app icon.
        case asset(String)
    }

    public var icon: Icon
    public var title: LocalizedStringResource
    public var message: LocalizedStringResource?
    public var features: [WelcomeFeature]

    /// Text parameters written as literals are looked up in the app's string catalog.
    public init(icon: Icon = .system("sparkles"), title: LocalizedStringResource, message: LocalizedStringResource? = nil,
                features: [WelcomeFeature] = []) {
        self.icon = icon
        self.title = title
        self.message = message
        self.features = features
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(icon) // Localized text is not Hashable.
        hasher.combine(features)
    }
}
