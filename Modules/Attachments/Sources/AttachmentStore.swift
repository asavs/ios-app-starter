import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// The files behind attachments: originals under a root in Application Support (the person's data,
/// backed up with the database that names them), thumbnails and link metadata under Caches
/// (rebuilt on demand, never backed up). One store per app; records keep `Attachment` values.
///
/// The store never reads a file's dates: `Attachment` records `createdAt` and `byteCount` itself.
public actor AttachmentStore: AttachmentStoring {
    public nonisolated let root: URL
    public nonisolated let cache: URL
    private let links: any LinkMetadataFetching
    private let fileManager = FileManager.default

    /// - Parameters:
    ///   - root: Where originals go, such as `Application Support/Attachments`.
    ///   - cache: Where thumbnails and link metadata go, such as `Caches/Attachments`.
    ///   - links: Fetches link metadata; a fake for tests.
    public init(root: URL, cache: URL, links: any LinkMetadataFetching = LinkMetadataFetcher()) {
        self.root = root
        self.cache = cache
        self.links = links
    }

    /// The app's store in its own container.
    public static func standard(links: any LinkMetadataFetching = LinkMetadataFetcher()) -> AttachmentStore {
        AttachmentStore(root: .applicationSupportDirectory.appending(path: "Attachments", directoryHint: .isDirectory),
                        cache: .cachesDirectory.appending(path: "Attachments", directoryHint: .isDirectory), links: links)
    }

    /// A fresh store under the temporary directory, for tests and previews.
    public static func temporary(links: any LinkMetadataFetching = FakeLinkMetadataFetcher()) -> AttachmentStore {
        let base = URL.temporaryDirectory.appending(path: "Attachments-\(UUID().uuidString)", directoryHint: .isDirectory)
        return AttachmentStore(root: base.appending(path: "Originals", directoryHint: .isDirectory),
                               cache: base.appending(path: "Cache", directoryHint: .isDirectory), links: links)
    }

    // MARK: Adding

    public func add(copying source: URL, displayName: String?, contentType: UTType?) async throws -> Attachment {
        let type = contentType ?? UTType(filenameExtension: source.pathExtension)
        let id = UUID()
        let destination = try fileURL(id: id, extension: type?.preferredFilenameExtension ?? source.pathExtension)
        try fileManager.copyItem(at: source, to: destination)
        return Attachment(id: id, kind: Attachment.kind(of: type),
                          displayName: displayName ?? source.lastPathComponent,
                          contentType: type?.identifier ?? UTType.data.identifier,
                          byteCount: try Self.byteCount(of: destination), relativePath: destination.lastPathComponent)
    }

    public func add(imageData: Data, contentType: UTType = .jpeg, displayName: String) async throws -> Attachment {
        let id = UUID()
        let destination = try fileURL(id: id, extension: contentType.preferredFilenameExtension ?? "jpg")
        try imageData.write(to: destination, options: .atomic)
        return Attachment(id: id, kind: .image, displayName: displayName, contentType: contentType.identifier,
                          byteCount: Int64(imageData.count), relativePath: destination.lastPathComponent)
    }

    public func add(link url: URL) async throws -> Attachment {
        let id = UUID()
        let metadata = try await links.fetch(url)
        try fileManager.createDirectory(at: linksDirectory, withIntermediateDirectories: true)
        try metadata.archive.write(to: linkCacheURL(id: id), options: .atomic)
        return Attachment(id: id, kind: .link, displayName: metadata.title ?? url.host() ?? url.absoluteString,
                          contentType: UTType.url.identifier, url: url)
    }

    // MARK: Reading

    public nonisolated func fileURL(for attachment: Attachment) -> URL? {
        attachment.relativePath.map { root.appending(path: $0) }
    }

    public func thumbnail(for attachment: Attachment, pixelSize: Int) async -> CGImage? {
        guard let file = fileURL(for: attachment) else { return nil }
        let cached = thumbnailURL(id: attachment.id)
        if let image = ThumbnailMaker.image(at: cached) { return image }
        guard let image = await ThumbnailMaker.make(for: file, kind: attachment.kind, pixelSize: pixelSize) else { return nil }
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        try? ThumbnailMaker.write(image, to: cached)
        return image
    }

    public func linkMetadataArchive(for attachment: Attachment) async -> Data? {
        guard attachment.isLink else { return nil }
        return try? Data(contentsOf: linkCacheURL(id: attachment.id))
    }

    // MARK: Removing

    public func remove(_ attachment: Attachment) async throws {
        for url in [fileURL(for: attachment), thumbnailURL(id: attachment.id), linkCacheURL(id: attachment.id)].compactMap({ $0 })
        where fileManager.fileExists(atPath: url.path()) {
            try fileManager.removeItem(at: url)
        }
    }

    public func sweep(keeping ids: Set<Attachment.ID>) async throws -> Int {
        var removed = 0
        for directory in [root, thumbnailsDirectory, linksDirectory] where fileManager.fileExists(atPath: directory.path()) {
            for url in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent), !ids.contains(id) else { continue }
                try fileManager.removeItem(at: url)
                if directory == root { removed += 1 }
            }
        }
        return removed
    }

    // MARK: Paths

    private var thumbnailsDirectory: URL { cache.appending(path: "Thumbnails", directoryHint: .isDirectory) }
    private var linksDirectory: URL { cache.appending(path: "Links", directoryHint: .isDirectory) }

    private func fileURL(id: UUID, extension ext: String) throws -> URL {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appending(path: ext.isEmpty ? id.uuidString : "\(id.uuidString).\(ext)")
    }

    private func thumbnailURL(id: UUID) -> URL { thumbnailsDirectory.appending(path: "\(id.uuidString).jpg") }
    private func linkCacheURL(id: UUID) -> URL { linksDirectory.appending(path: "\(id.uuidString).plist") }

    private static func byteCount(of url: URL) throws -> Int64 {
        Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
    }
}
