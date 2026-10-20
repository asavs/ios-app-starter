import Foundation

/// A `SecureStore` that keeps values in memory: for tests, previews and host-side runs.
///
/// It is not secure storage. Use it where the Keychain is unavailable or would leave state behind.
public final class InMemorySecureStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data]

    public init(_ initial: [String: Data] = [:]) {
        storage = initial
    }

    public func data(for key: String) throws -> Data? {
        lock.withLock { storage[key] }
    }

    public func set(_ data: Data, for key: String) throws {
        lock.withLock { storage[key] = data }
    }

    public func remove(_ key: String) throws {
        lock.withLock { storage[key] = nil }
    }

    public func removeAll() throws {
        lock.withLock { storage.removeAll() }
    }

    public func keys() throws -> [String] {
        lock.withLock { Array(storage.keys) }
    }
}
