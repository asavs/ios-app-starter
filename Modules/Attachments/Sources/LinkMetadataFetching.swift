import Foundation
#if canImport(LinkPresentation)
import LinkPresentation
#endif

/// A link's title and its `LPLinkMetadata` as a secure-coding archive, ready to cache.
public struct LinkMetadata: Sendable, Equatable {
    public var title: String?
    public var archive: Data

    public init(title: String?, archive: Data) {
        self.title = title
        self.archive = archive
    }
}

/// Fetches a link's metadata. The real one asks the site from this device, so the store calls it
/// once, when a person adds the link, and caches the answer; a fake answers offline.
public protocol LinkMetadataFetching: Sendable {
    func fetch(_ url: URL) async throws -> LinkMetadata
}

#if canImport(LinkPresentation)
/// `LPMetadataProvider`, one per request, with a short timeout.
public struct LinkMetadataFetcher: LinkMetadataFetching {
    private let timeout: TimeInterval

    public init(timeout: Duration = .seconds(10)) {
        self.timeout = TimeInterval(timeout.components.seconds)
    }

    public func fetch(_ url: URL) async throws -> LinkMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = timeout
        let metadata = try await provider.startFetchingMetadata(for: url)
        return try LinkMetadata(title: metadata.title, archive: Self.archive(metadata))
    }

    static func archive(_ metadata: LPLinkMetadata) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: metadata, requiringSecureCoding: true)
    }

    /// The metadata back from a store's archive, for `LPLinkView`.
    public static func metadata(from archive: Data) -> LPLinkMetadata? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: LPLinkMetadata.self, from: archive)
    }
}

/// Answers with a fixed title and no network, for tests and the `-attachments.fakeLink` argument.
public struct FakeLinkMetadataFetcher: LinkMetadataFetching {
    public var title: String

    public init(title: String = "Example") {
        self.title = title
    }

    public func fetch(_ url: URL) async throws -> LinkMetadata {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        return try LinkMetadata(title: title, archive: LinkMetadataFetcher.archive(metadata))
    }
}
#else
public struct LinkMetadataFetcher: LinkMetadataFetching {
    public init(timeout: Duration = .seconds(10)) {}
    public func fetch(_ url: URL) async throws -> LinkMetadata { throw CocoaError(.featureUnsupported) }
}

public struct FakeLinkMetadataFetcher: LinkMetadataFetching {
    public var title: String
    public init(title: String = "Example") { self.title = title }
    public func fetch(_ url: URL) async throws -> LinkMetadata { LinkMetadata(title: title, archive: Data()) }
}
#endif
