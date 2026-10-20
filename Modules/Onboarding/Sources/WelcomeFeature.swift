import Foundation

/// One row of the welcome step: a symbol, a short title and one sentence of detail.
public struct WelcomeFeature: Identifiable, Sendable, Equatable, Hashable {
    public var id: String
    public var systemImage: String
    public var title: String
    public var detail: String

    /// - Parameter id: Stable identity for the list; defaults to the title.
    public init(id: String? = nil, systemImage: String, title: String, detail: String) {
        self.id = id ?? title
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }
}
