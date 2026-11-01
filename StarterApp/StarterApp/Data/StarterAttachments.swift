import Foundation
#if canImport(Attachments)
import Attachments
#if canImport(Settings)
import Settings
#endif

/// The app's attachment store: files under Application Support, thumbnails and link metadata
/// under Caches. A UI-test launch keeps them under its own directory instead, emptied on a `resets`
/// launch, unless the test names a root itself (`-attachments.root`, see `AttachmentTestOverrides`).
enum StarterAttachments {
    static let store = store(for: UITestLaunch.current, overrides: .current)

    static func store(for launch: UITestLaunch?, overrides: AttachmentTestOverrides) -> AttachmentStore {
        var overrides = overrides
        if let launch, overrides.root == nil {
            overrides.root = UITestLaunch.directory.appending(path: "Attachments", directoryHint: .isDirectory)
            overrides.reset = launch.resets
        }
        return overrides.store()
    }

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
