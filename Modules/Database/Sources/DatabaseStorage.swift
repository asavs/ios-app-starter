import Foundation

/// Where a `ModelContainer` keeps its store: a file on disk, or memory for previews and tests.
public enum DatabaseStorage: Sendable, Equatable {
    /// A SQLite store at this URL (its `-wal` and `-shm` sidecars sit beside it).
    case persistent(URL)
    /// Nothing is written to disk; the data lives as long as the container.
    case memory

    /// `<Application Support>/<name>.store`, the usual place for an app's own database.
    public static func applicationSupport(named name: String) -> DatabaseStorage {
        let directory = URL.applicationSupportDirectory
        return .persistent(directory.appending(path: "\(name).store"))
    }

    var url: URL? {
        if case .persistent(let url) = self { return url }
        return nil
    }
}
