import Foundation
import Testing
@testable import TabShell

struct TabItemTests {
    @Test func translatingOrBadgingATabDoesNotChangeIdentity() {
        let original = TabItem(id: TestTab.library, title: "Library", systemImage: "books.vertical")
        let translated = TabItem(id: TestTab.library, title: "Bibliothek", systemImage: "books.vertical", badgeCount: 3)
        #expect(original.id == translated.id)
        #expect(original.accessibilityIdentifier == "tabs.library")
        #expect(translated.accessibilityIdentifier == original.accessibilityIdentifier)
        #expect(translated.badgeCount == 3)
    }

    @Test(arguments: [-1, 0, 1, 42])
    func badgeCountsAreNeverNegative(_ count: Int) {
        let tab = TabItem(id: TestTab.activity, title: "Activity", systemImage: "bell", badgeCount: count)
        #expect(tab.badgeCount == max(0, count))
    }
}
