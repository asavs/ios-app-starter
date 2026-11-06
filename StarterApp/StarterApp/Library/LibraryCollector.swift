import Foundation
import Observation
#if canImport(Database) && canImport(Attachments)
import Attachments

/// Turns what the picker imported into Library items, through the coordinator, which saves the
/// owner. When that save fails the file is already in the store, so the attachment is kept aside
/// for Try Again or Discard rather than left as a file nothing owns (docs/research/library.md).
@MainActor @Observable
final class LibraryCollector {
    /// Set once the store is open; an import before then is kept for a retry.
    var coordinator: ContentCoordinator?
    /// Imported into the store but not yet owned by a saved item.
    private(set) var unsaved: [Attachment] = []
    /// The last failure, for the alert; nil once resolved.
    var failure: String?
    private let store: any AttachmentStoring

    init(store: any AttachmentStoring) {
        self.store = store
    }

    /// Each attachment becomes an item titled with its display name.
    func collect(_ added: [Attachment]) {
        for attachment in added {
            do {
                guard let coordinator else { throw NotReady() }
                try coordinator.collect(attachment, title: attachment.displayName)
            } catch {
                unsaved.append(attachment)
                failure = error.localizedDescription
            }
        }
    }

    /// Save the kept attachments again.
    func retry() {
        let pending = unsaved
        unsaved = []
        failure = nil
        collect(pending)
    }

    /// Give up on the kept attachments: their files go, since nothing owns them. The removal is
    /// returned for a test to await; the screen has nothing to show for it.
    @discardableResult
    func discard() -> Task<Void, Never> {
        let pending = unsaved
        unsaved = []
        failure = nil
        let store = store
        return Task {
            for attachment in pending {
                try? await store.remove(attachment) // A file that stays is harmless; the next erase sweeps it.
            }
        }
    }

    var hasFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    private struct NotReady: LocalizedError {
        var errorDescription: String? { String(localized: "The Library wasn't ready to save this item.") }
    }
}
#endif
