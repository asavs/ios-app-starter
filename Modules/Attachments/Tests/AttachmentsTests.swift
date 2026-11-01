import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Attachments

/// Swift Testing has an `Attachment` of its own; the module's is meant throughout.
private typealias Attachment = Attachments.Attachment

/// The store against a temporary directory: placement, thumbnails, links, removal and the sweep.
struct AttachmentsTests {
    private let store = AttachmentStore.temporary(links: FakeLinkMetadataFetcher(title: "Apple"))

    private func sampleFile(named name: String, bytes: Int = 1234) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "AttachmentsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try Data(repeating: 7, count: bytes).write(to: url)
        return url
    }

    @Test func copiesAPickedFileUnderItsIdentifierAndRecordsWhatItIs() async throws {
        let source = try sampleFile(named: "invoice.pdf")
        let attachment = try await store.add(copying: source, displayName: nil, contentType: .pdf)
        #expect(attachment.kind == .file)
        #expect(attachment.displayName == "invoice.pdf")
        #expect(attachment.contentType == UTType.pdf.identifier)
        #expect(attachment.byteCount == 1234)
        #expect(attachment.relativePath == "\(attachment.id.uuidString).pdf")
        let stored = try #require(store.fileURL(for: attachment))
        #expect(FileManager.default.fileExists(atPath: stored.path()))
        #expect(stored.deletingLastPathComponent() == store.root)
        #expect(FileManager.default.fileExists(atPath: source.path()), "The source is copied, never moved")
    }

    @Test func infersTheKindFromTheContentType() async throws {
        let jpeg = try #require(ThumbnailMaker.sampleJPEG())
        let image = try await store.add(imageData: jpeg, contentType: .jpeg, displayName: "Photo")
        #expect(image.kind == .image)
        #expect(image.byteCount == Int64(jpeg.count))
        #expect(Attachment.kind(of: .mpeg4Movie) == .movie)
        #expect(Attachment.kind(of: .plainText) == .file)
        #expect(Attachment.kind(of: nil) == .file)
        let source = try sampleFile(named: "clip.mov")
        let movie = try await store.add(copying: source, displayName: "Clip", contentType: nil)
        #expect(movie.kind == .movie, "The extension decides when no type is given")
        #expect(movie.displayName == "Clip")
    }

    @Test func makesAndCachesAThumbnailForAnImage() async throws {
        let jpeg = try #require(ThumbnailMaker.sampleJPEG(width: 900, height: 600))
        let attachment = try await store.add(imageData: jpeg, contentType: .jpeg, displayName: "Photo")
        let thumbnail = try #require(await store.thumbnail(for: attachment, pixelSize: 300))
        #expect(max(thumbnail.width, thumbnail.height) <= 300)
        let cached = store.cache.appending(path: "Thumbnails/\(attachment.id.uuidString).jpg")
        #expect(FileManager.default.fileExists(atPath: cached.path()), "The thumbnail is written under Caches")
        let again = try #require(await store.thumbnail(for: attachment, pixelSize: 300))
        #expect(again.width == thumbnail.width)
    }

    @Test func aLinkKeepsItsTitleAndCachesItsMetadata() async throws {
        let url = try #require(URL(string: "https://www.apple.com/iphone/"))
        let link = try await store.add(link: url)
        #expect(link.kind == .link)
        #expect(link.isLink)
        #expect(link.url == url)
        #expect(link.displayName == "Apple")
        #expect(link.contentType == UTType.url.identifier)
        #expect(store.fileURL(for: link) == nil)
        #expect(await store.thumbnail(for: link, pixelSize: 100) == nil)
        let archive = try #require(await store.linkMetadataArchive(for: link))
        #expect(archive.isEmpty == false)
#if canImport(LinkPresentation)
        #expect(LinkMetadataFetcher.metadata(from: archive)?.title == "Apple")
#endif
    }

    @Test func removingDeletesTheFileAndItsCaches() async throws {
        let jpeg = try #require(ThumbnailMaker.sampleJPEG())
        let attachment = try await store.add(imageData: jpeg, contentType: .jpeg, displayName: "Photo")
        _ = await store.thumbnail(for: attachment, pixelSize: 100)
        let file = try #require(store.fileURL(for: attachment))
        try await store.remove(attachment)
        #expect(FileManager.default.fileExists(atPath: file.path()) == false)
        #expect(FileManager.default.fileExists(atPath: store.cache.appending(path: "Thumbnails/\(attachment.id.uuidString).jpg").path()) == false)
        try await store.remove(attachment) // Already gone: not an error.
    }

    @Test func theSweepKeepsWhatTheAppStillNames() async throws {
        let kept = try await store.add(copying: try sampleFile(named: "a.txt"), displayName: nil, contentType: .plainText)
        let orphan = try await store.add(copying: try sampleFile(named: "b.txt"), displayName: nil, contentType: .plainText)
        let link = try await store.add(link: try #require(URL(string: "https://example.com")))
        _ = await store.thumbnail(for: kept, pixelSize: 50)
        let removed = try await store.sweep(keeping: [kept.id])
        #expect(removed == 1)
        let keptFile = try #require(store.fileURL(for: kept))
        let orphanFile = try #require(store.fileURL(for: orphan))
        #expect(FileManager.default.fileExists(atPath: keptFile.path()))
        #expect(FileManager.default.fileExists(atPath: orphanFile.path()) == false)
        #expect(await store.linkMetadataArchive(for: link) == nil, "The orphaned link's cache goes too")
    }

    @Test func attachmentsRoundTripThroughCodable() throws {
        let attachment = Attachment(kind: .link, displayName: "Apple", contentType: UTType.url.identifier,
                                    url: URL(string: "https://apple.com"))
        let data = try JSONEncoder().encode([attachment])
        let decoded = try JSONDecoder().decode([Attachment].self, from: data)
        #expect(decoded == [attachment])
        #expect(attachment.type == .url)
    }

    @Test func overridesComeFromLaunchArguments() {
        let none = AttachmentTestOverrides(arguments: ["-other", "x"])
        #expect(none == AttachmentTestOverrides())
        let all = AttachmentTestOverrides(arguments: ["-attachments.root", "/tmp/att", "-attachments.reset", "-attachments.fakeCamera",
                                                     "-attachments.fakePhotos", "-attachments.fakeLink", "Fake Title"])
        #expect(all.root?.path() == "/tmp/att/")
        #expect(all.reset && all.fakeCamera && all.fakePhotos)
        #expect(all.fakeLink == "Fake Title")
        let store = all.store()
        #expect(store.root.path().hasPrefix("/tmp/att/"))
    }

    @Test func theSampleImageIsAJPEG() throws {
        let data = try #require(ThumbnailMaker.sampleJPEG(width: 64, height: 48))
        #expect(data.starts(with: [0xFF, 0xD8]), "JPEG magic bytes")
    }
}
