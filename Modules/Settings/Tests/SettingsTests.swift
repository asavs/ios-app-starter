import Foundation
import SwiftUI
import Testing
import Theme
@testable import Settings

struct SettingsTests {
    /// A throwaway defaults domain so tests never touch the host's standard defaults.
    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "SettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    // MARK: Preferences

    @Test func appearanceDefaultsToSystemAndPersists() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.appearance == .system)
        settings.appearance = .dark
        #expect(settings.appearance == .dark)
        #expect(defaults.string(forKey: AppSettings.appearanceKey) == "dark")
        #expect(AppSettings(defaults: defaults).appearance == .dark)
    }

    @Test func unknownStoredAppearanceFallsBackToSystem() throws {
        let defaults = try isolatedDefaults()
        defaults.set("sepia", forKey: AppSettings.appearanceKey)
        #expect(AppSettings(defaults: defaults).appearance == .system)
    }

    @Test func resetForgetsEveryKey() throws {
        let defaults = try isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.appearance = .light
        settings.reset()
        #expect(settings.appearance == .system)
        for key in AppSettings.keys {
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test func keysAreStableForLaunchArguments() {
        #expect(AppSettings.appearanceKey == "settings.appearance")
        #expect(AppSettings.keys == ["settings.appearance"])
    }

    @Test func versionFormatsLikeTheAppStore() {
        #expect(AppInfo.format(version: "1.0", build: "42") == "1.0 (42)")
        #expect(AppInfo.format(version: "1.0", build: "1.0") == "1.0")
        #expect(AppInfo.format(version: "1.0", build: nil) == "1.0")
        #expect(AppInfo.format(version: "", build: "7") == "7")
        #expect(AppInfo.format(version: nil, build: nil) == nil)
    }

    // MARK: Secure store

    @Test func inMemoryStoreRoundTripsAndRemoves() throws {
        let store = InMemorySecureStore()
        #expect(try store.string(for: "token") == nil)
        #expect(try !store.contains("token"))
        try store.set("secret", for: "token")
        #expect(try store.string(for: "token") == "secret")
        #expect(try store.contains("token"))
        try store.set("replaced", for: "token")
        #expect(try store.string(for: "token") == "replaced")
        try store.set(Data([0xff, 0xfe]), for: "blob")
        #expect(try store.data(for: "blob") == Data([0xff, 0xfe]))
        #expect(try Set(store.keys()) == ["token", "blob"])
        try store.remove("token")
        try store.remove("token") // Removing a missing key is not an error.
        #expect(try store.string(for: "token") == nil)
        try store.removeAll()
        #expect(try store.keys().isEmpty)
    }

    @Test func nonTextBytesAreReportedNotMangled() throws {
        let store = InMemorySecureStore(["blob": Data([0xff, 0xfe])])
        #expect(throws: SecureStoreError.invalidEncoding(key: "blob")) {
            try store.string(for: "blob")
        }
        #expect(SecureStoreError.keychain(status: -25300, operation: "read").description.contains("-25300"))
    }

    @Test @MainActor func performRunsOffTheMainThreadAndPassesErrorsThrough() async throws {
        let store: any SecureStore = InMemorySecureStore(["blob": Data([0xff])])
        let ranOnMain = try await store.perform { _ in Thread.isMainThread }
        #expect(!ranOnMain, "Keychain calls block their thread, so perform must leave the main actor")
        try await store.perform { try $0.set("value", for: "token") }
        #expect(try await store.perform { try $0.string(for: "token") } == "value")
        await #expect(throws: SecureStoreError.invalidEncoding(key: "blob")) {
            try await store.perform { try $0.string(for: "blob") }
        }
    }

#if os(iOS)
    /// Whether this process may use the Keychain. Xcode's package test host has no application
    /// identifier, so the simulator Keychain answers errSecMissingEntitlement (-34018) there and
    /// these tests are skipped with that reason; the app's UI test exercises the real Keychain
    /// with an ad hoc signed app. In an app-hosted test target they run.
    static let keychainAvailable: Bool = {
        let probe = KeychainStore(service: "SettingsTests.probe.\(UUID().uuidString)")
        defer { try? probe.removeAll() }
        do {
            try probe.set("probe", for: "probe")
            return true
        } catch SecureStoreError.keychain(let status, _) where status == errSecMissingEntitlement {
            return false
        } catch {
            return true // Any other failure should surface in the tests below.
        }
    }()

    /// Keychain items are scoped by service; each test uses its own and removes it afterwards.
    private func keychain(_ accessibility: KeychainStore.Accessibility = .afterFirstUnlock) -> KeychainStore {
        KeychainStore(service: "SettingsTests.\(UUID().uuidString)", accessibility: accessibility)
    }

    @Test(.enabled(if: Self.keychainAvailable, "test host has no application identifier; the app UI test covers the Keychain"))
    func keychainRoundTripsReplacesAndRemoves() throws {
        let store = keychain()
        defer { try? store.removeAll() }
        #expect(try store.string(for: "token") == nil)
        try store.set("secret", for: "token")
        #expect(try store.string(for: "token") == "secret")
        try store.set("replaced", for: "token")
        #expect(try store.string(for: "token") == "replaced")
        #expect(try store.keys() == ["token"])
        try store.remove("token")
        try store.remove("token")
        #expect(try store.string(for: "token") == nil)
        #expect(try store.keys().isEmpty)
    }

    @Test(.enabled(if: Self.keychainAvailable, "test host has no application identifier; the app UI test covers the Keychain"))
    func keychainServicesAreIsolated() throws {
        let first = keychain()
        let second = keychain(.whenUnlocked)
        defer { try? first.removeAll(); try? second.removeAll() }
        try first.set("one", for: "shared")
        try second.set("two", for: "shared")
        try second.set("extra", for: "other")
        #expect(try first.string(for: "shared") == "one")
        #expect(try second.string(for: "shared") == "two")
        try first.removeAll()
        #expect(try first.keys().isEmpty)
        #expect(try Set(second.keys()) == ["shared", "other"])
    }

    @Test(.enabled(if: Self.keychainAvailable, "test host has no application identifier; the app UI test covers the Keychain"))
    func keychainStoresRawData() throws {
        let store = keychain()
        defer { try? store.removeAll() }
        try store.set(Data([0x00, 0xff, 0x10]), for: "blob")
        #expect(try store.data(for: "blob") == Data([0x00, 0xff, 0x10]))
        #expect(throws: SecureStoreError.invalidEncoding(key: "blob")) { try store.string(for: "blob") }
    }
#endif

    @Test func keychainDefaultsToTheBundleAndDeviceOnlyAccess() {
        let store = KeychainStore()
        #expect(store.service == KeychainStore.defaultService)
        #expect(!store.service.isEmpty)
        #expect(store.accessibility == .afterFirstUnlock)
        #expect(KeychainStore.Accessibility.afterFirstUnlock.attribute == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        #expect(KeychainStore.Accessibility.whenUnlocked.attribute == kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    }

    // MARK: Views

    @Test @MainActor func viewsConstructWithPublicInitializers() throws {
        _ = SettingsView()
        _ = SettingsView(version: nil)
        _ = SettingsView(version: "1.0 (1)") {
            Section("Account") { SecureSettingRow("API key", key: "api.key", store: InMemorySecureStore()) }
        }
        _ = SecureSettingRow("Token", key: "token")
        _ = Text("Root").storedAppearance()
        _ = Text("Root").storedAppearance(store: try isolatedDefaults())
    }
}
