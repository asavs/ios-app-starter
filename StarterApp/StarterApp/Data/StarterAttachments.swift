import Foundation
#if canImport(Attachments)
import Attachments
#if canImport(Settings)
import Settings
#endif

/// The app's attachment store: files under Application Support, thumbnails and link metadata
/// under Caches. UI tests point it elsewhere with `-attachments.root` (see `AttachmentTestOverrides`).
enum StarterAttachments {
    static let store = AttachmentTestOverrides.current.store()

#if canImport(Settings)
    /// Erase Local Data removes every stored file and cache; the records that named them go with
    /// the database step.
    static var resetStep: LocalDataReset.Step {
        LocalDataReset.Step("attachments") {
            for directory in [store.root, store.cache] where FileManager.default.fileExists(atPath: directory.path()) {
                try FileManager.default.removeItem(at: directory)
            }
        }
    }
#endif
}
#endif
