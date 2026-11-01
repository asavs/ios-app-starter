import Foundation
import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// What the picker menu does once a person chooses: copies picked photos and files into the store,
/// stores a capture, records a link, and reports each new attachment and any failure. The views
/// only present the system pickers and bind to this.
@MainActor @Observable
public final class AttachmentPickerModel {
    public enum Presentation: Equatable {
        case photos, camera, files, link
    }

    public let store: any AttachmentStoring
    public let sources: AttachmentSource
    public let allowedContentTypes: [UTType]
    public let maxPhotoSelection: Int
    private let overrides: AttachmentTestOverrides
    private let onAdd: ([Attachment]) -> Void

    /// Which system picker is up, if any.
    public var presentation: Presentation?
    /// Photos the person picked; loading them is the work.
    public var photoItems: [PhotosPickerItem] = []
    /// The link being typed.
    public var linkText = ""
    /// How many imports are underway, for a progress indicator.
    public private(set) var importsInProgress = 0
    /// The last failure, for an alert; nil once dismissed.
    public var failure: String?

    public init(store: any AttachmentStoring, sources: AttachmentSource = .all, allowedContentTypes: [UTType] = [.item],
                maxPhotoSelection: Int = 10, overrides: AttachmentTestOverrides = .current,
                onAdd: @escaping ([Attachment]) -> Void) {
        self.store = store
        self.sources = sources
        self.allowedContentTypes = allowedContentTypes
        self.maxPhotoSelection = maxPhotoSelection
        self.overrides = overrides
        self.onAdd = onAdd
    }

    /// The menu entries to show: the camera only where there is one (or a fake).
    public var availableSources: AttachmentSource {
        var available = sources
        if !Self.hasCamera && !overrides.fakeCamera { available.remove(.camera) }
        return available
    }

    public static var hasCamera: Bool {
#if os(iOS)
        UIImagePickerController.isSourceTypeAvailable(.camera)
#else
        false
#endif
    }

    public func choosePhotos() {
        if overrides.fakePhotos {
            addSample(named: "Photo")
        } else {
            presentation = .photos
        }
    }

    public func chooseCamera() {
        if overrides.fakeCamera {
            addSample(named: "Capture")
        } else {
            presentation = .camera
        }
    }

    public func chooseFiles() {
        presentation = .files
    }

    public func chooseLink() {
        linkText = ""
        presentation = .link
    }

    /// Picked photos arrived: load each as a file into the store, one task per item.
    public func photosChanged() {
        let items = photoItems
        photoItems = []
        for item in items {
            run {
                let type = item.supportedContentTypes.first { $0.conforms(to: .image) || $0.conforms(to: .movie) }
                guard let imported = try await item.loadTransferable(type: ImportedFile.self) else {
                    throw AttachmentImportError.unsupported
                }
                defer { try? FileManager.default.removeItem(at: imported.url) }
                return try await self.store.add(copying: imported.url, displayName: nil, contentType: type)
            }
        }
    }

    /// The Files picker's result: security-scoped URLs that are copied while access is held.
    public func filesPicked(_ result: Result<[URL], any Error>) {
        switch result {
        case .failure(let error):
            failure = error.localizedDescription
        case .success(let urls):
            for url in urls {
                run {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    return try await self.store.add(copying: url, displayName: url.lastPathComponent,
                                                    contentType: UTType(filenameExtension: url.pathExtension))
                }
            }
        }
    }

    /// A capture's encoded bytes from the camera sheet.
    public func captured(_ data: Data, contentType: UTType = .jpeg) {
        run { try await self.store.add(imageData: data, contentType: contentType, displayName: Self.captureName()) }
    }

    /// The typed link, once Add is tapped.
    public func addLink() {
        let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = Self.webURL(from: text) else {
            failure = String(localized: "That doesn't look like a web address.", bundle: .module)
            return
        }
        run { try await self.store.add(link: url) }
    }

    /// `https://` is assumed when the scheme is missing; only web links are accepted.
    static func webURL(from text: String) -> URL? {
        guard !text.isEmpty else { return nil }
        let candidate = text.contains("://") ? text : "https://\(text)"
        guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), host.contains(".") else { return nil }
        return url
    }

    static func captureName(date: Date = .now) -> String {
        String(localized: "Photo \(date.formatted(date: .abbreviated, time: .shortened))", bundle: .module)
    }

    private func addSample(named name: String) {
        run {
            guard let data = ThumbnailMaker.sampleJPEG() else { throw AttachmentImportError.unsupported }
            return try await self.store.add(imageData: data, contentType: .jpeg, displayName: name)
        }
    }

    /// One import: counted while it runs, reported when it lands, its failure kept for the alert.
    private func run(_ work: @escaping @MainActor () async throws -> Attachment) {
        importsInProgress += 1
        Task {
            defer { importsInProgress -= 1 }
            do {
                onAdd([try await work()])
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

enum AttachmentImportError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        String(localized: "This item can't be attached.", bundle: .module)
    }
}
