import Foundation

/// Third-party code, art or help an app credits on its Acknowledgements screen.
///
/// The list is kept by hand: the app adds an entry when it adopts a dependency. Generating it from
/// `Package.resolved` can come later as a script; fetching licences at run time (as AcknowList does)
/// would make a network call from a privacy-minded screen.
public struct Acknowledgement: Equatable, Identifiable, Sendable {
    public var id: String
    /// What is credited: a package, a typeface, an artist.
    public var name: String
    public var author: String?
    /// The licence or terms, such as "MIT License".
    public var license: LocalizedStringResource?
    /// Where to read more; the row opens it.
    public var url: URL?

    public init(id: String? = nil, name: String, author: String? = nil, license: LocalizedStringResource? = nil, url: URL? = nil) {
        self.id = id ?? name
        self.name = name
        self.author = author
        self.license = license
        self.url = url
    }
}
