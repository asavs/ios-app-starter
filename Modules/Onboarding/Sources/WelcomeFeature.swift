import Foundation

/// One row of the welcome step: a symbol, a short title and one sentence of detail.
public struct WelcomeFeature: Identifiable, Sendable, Equatable, Hashable {
    /// Stable identity for the list and the row's accessibility identifier; never shown.
    public var id: String
    public var systemImage: String
    public var title: LocalizedStringResource
    public var detail: LocalizedStringResource

    /// Text parameters written as literals are looked up in the app's string catalog.
    public init(id: String, systemImage: String, title: LocalizedStringResource, detail: LocalizedStringResource) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id) // Localized text is not Hashable; equal rows share an identifier.
    }
}
