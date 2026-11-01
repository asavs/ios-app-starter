import Foundation

/// Launch arguments that keep UI tests off the camera, the network and the shared container:
/// `-attachments.root <directory>` stores files there (emptied first with `-attachments.reset`),
/// `-attachments.fakeCamera` makes the Camera entry add a generated photo, `-attachments.fakePhotos`
/// does the same for Photos (the system picker runs out of process), and `-attachments.fakeLink
/// <title>` answers link metadata offline. Read from the process arguments, so the module needs no privacy manifest reason.
public struct AttachmentTestOverrides: Sendable, Equatable {
    public var root: URL?
    public var reset: Bool
    public var fakeCamera: Bool
    public var fakePhotos: Bool
    public var fakeLink: String?

    public init(root: URL? = nil, reset: Bool = false, fakeCamera: Bool = false, fakePhotos: Bool = false, fakeLink: String? = nil) {
        self.root = root
        self.reset = reset
        self.fakeCamera = fakeCamera
        self.fakePhotos = fakePhotos
        self.fakeLink = fakeLink
    }

    public init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        self.init(root: value(after: "-attachments.root").map { URL(filePath: $0, directoryHint: .isDirectory) },
                  reset: arguments.contains("-attachments.reset"),
                  fakeCamera: arguments.contains("-attachments.fakeCamera"),
                  fakePhotos: arguments.contains("-attachments.fakePhotos"),
                  fakeLink: value(after: "-attachments.fakeLink"))
    }

    public static let current = AttachmentTestOverrides(arguments: ProcessInfo.processInfo.arguments)

    /// The store these overrides ask for: the app's own, or one under `root`.
    public func store() -> AttachmentStore {
        let links: any LinkMetadataFetching = fakeLink.map { FakeLinkMetadataFetcher(title: $0) } ?? LinkMetadataFetcher()
        guard let root else { return AttachmentStore.standard(links: links) }
        if reset { try? FileManager.default.removeItem(at: root) }
        return AttachmentStore(root: root.appending(path: "Originals", directoryHint: .isDirectory),
                               cache: root.appending(path: "Cache", directoryHint: .isDirectory), links: links)
    }
}
