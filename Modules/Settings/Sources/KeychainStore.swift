import Foundation
import Security

/// Secrets in the device Keychain as generic-password items.
///
/// Items are scoped by `service` (the app's bundle identifier by default) and keyed by account, so
/// an app's values never collide with another app's. No entitlement is needed for an app's own
/// items; sharing across an app group or with iCloud Keychain is a deliberate later step. Values
/// are available after the first unlock and never migrate to another device by default.
///
/// On macOS the items go to the login keychain; the simulator and iOS lanes are the supported
/// checks, and the module's Keychain tests run on iOS only.
public struct KeychainStore: SecureStore {
    /// When the system lets the app read an item. Every case is device-bound (`ThisDeviceOnly`).
    public enum Accessibility: Sendable, Equatable {
        /// Readable after the first unlock since boot, including in the background. The default.
        case afterFirstUnlock
        /// Readable only while the device is unlocked.
        case whenUnlocked

        var attribute: CFString {
            switch self {
            case .afterFirstUnlock: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .whenUnlocked: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            }
        }
    }

    public let service: String
    public let accessibility: Accessibility

    /// The default service: the main bundle identifier, or `StarterModules.Settings` without one.
    public static var defaultService: String {
        Bundle.main.bundleIdentifier ?? "StarterModules.Settings"
    }

    public init(service: String = KeychainStore.defaultService, accessibility: Accessibility = .afterFirstUnlock) {
        self.service = service
        self.accessibility = accessibility
    }

    public func data(for key: String) throws -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw SecureStoreError.keychain(status: status, operation: "read")
        }
    }

    public func set(_ data: Data, for key: String) throws {
        var item = baseQuery(key: key)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = accessibility.attribute
        let added = SecItemAdd(item as CFDictionary, nil)
        guard added == errSecDuplicateItem else {
            if added != errSecSuccess { throw SecureStoreError.keychain(status: added, operation: "add") }
            return
        }
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility.attribute,
        ]
        let updated = SecItemUpdate(baseQuery(key: key) as CFDictionary, update as CFDictionary)
        guard updated == errSecSuccess else {
            throw SecureStoreError.keychain(status: updated, operation: "update")
        }
    }

    public func remove(_ key: String) throws {
        try delete(baseQuery(key: key), operation: "remove")
    }

    public func removeAll() throws {
        var query = baseQuery(key: nil)
#if os(macOS)
        query[kSecMatchLimit as String] = kSecMatchLimitAll // The file keychain deletes one item otherwise.
#endif
        try delete(query, operation: "remove all")
    }

    public func keys() throws -> [String] {
        var query = baseQuery(key: nil)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            let items = result as? [[String: Any]] ?? []
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        case errSecItemNotFound:
            return []
        default:
            throw SecureStoreError.keychain(status: status, operation: "list")
        }
    }

    private func baseQuery(key: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let key {
            query[kSecAttrAccount as String] = key
        }
        return query
    }

    private func delete(_ query: [String: Any], operation: String) throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.keychain(status: status, operation: operation)
        }
    }
}
