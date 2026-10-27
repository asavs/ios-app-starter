import Foundation
import Testing
@testable import StarterApp

struct DeepLinkTests {
    private let schemes: Set<String> = ["starterapp"]

    @Test(arguments: [
        ("starterapp://settings", "settings"),
        ("starterapp://welcome/", "welcome"),
        ("StarterApp://settings", "settings"), // Schemes are case-insensitive.
    ])
    func tabLinks(link: String, tab: String) throws {
        #expect(DeepLink.tab(in: try #require(URL(string: link)), schemes: schemes) == tab)
    }

    @Test(arguments: [
        "https://settings",             // Another scheme.
        "otherapp://settings",
        "starterapp:settings",          // No host.
        "starterapp://",
        "starterapp://settings/secrets", // Routes inside a tab are the app's to add.
        "starterapp://settings?reset=tips",
        "starterapp://settings#top",
        "starterapp://user@settings",
        "starterapp://settings:8080",
    ])
    func rejectsOtherURLs(link: String) throws {
        #expect(DeepLink.tab(in: try #require(URL(string: link)), schemes: schemes) == nil)
    }

    @Test func appRegistersItsScheme() {
        #expect(!DeepLink.registeredSchemes.isEmpty, "project.yml should register APP_URL_SCHEME")
    }
}
