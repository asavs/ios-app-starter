import Foundation

/// Key-value storage for secrets: tokens, passwords, API keys.
///
/// `KeychainStore` is the production implementation; `InMemorySecureStore` stands in for tests and
/// previews. Keys are plain strings an app chooses (`"api.token"`). Values are `Data`; the `String`
/// helpers encode UTF-8. Nothing here belongs in `UserDefaults`, which is readable from a backup.
public protocol SecureStore: Sendable {
    /// The stored value, or `nil` when the key has none.
    func data(for key: String) throws -> Data?
    /// Stores or replaces the value.
    func set(_ data: Data, for key: String) throws
    /// Removes the value; removing a missing key is not an error.
    func remove(_ key: String) throws
    /// Removes every value this store holds.
    func removeAll() throws
    /// The keys with a value, in no particular order.
    func keys() throws -> [String]
}

public extension SecureStore {
    func string(for key: String) throws -> String? {
        guard let data = try data(for: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.invalidEncoding(key: key)
        }
        return string
    }

    func set(_ string: String, for key: String) throws {
        try set(Data(string.utf8), for: key)
    }

    func contains(_ key: String) throws -> Bool {
        try data(for: key) != nil
    }

    /// Runs store calls off the caller's actor: `try await store.perform { try $0.contains("api.token") }`.
    ///
    /// Keychain calls block the calling thread, which Apple warns "can cause your app's UI to hang if
    /// called from the main thread", so views and other main-actor code go through this. A
    /// nonisolated async function runs on the global concurrent executor in this package's language
    /// mode. It is a separate name rather than async overloads of the methods above, which would
    /// make existing calls inside async functions need `await`.
    nonisolated func perform<Result: Sendable>(_ work: @Sendable (Self) throws -> Result) async throws -> Result {
        try work(self)
    }
}

public enum SecureStoreError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The stored bytes are not UTF-8; read them with `data(for:)` instead.
    case invalidEncoding(key: String)
    /// A Security framework call failed; `status` is the `OSStatus` it returned.
    case keychain(status: Int32, operation: String)

    public var description: String {
        switch self {
        case .invalidEncoding(let key):
            "value for \(key) is not UTF-8 text"
        case .keychain(let status, let operation):
            "Keychain \(operation) failed with status \(status)"
        }
    }
}
