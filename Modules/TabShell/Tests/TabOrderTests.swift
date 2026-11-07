import Testing
@testable import TabShell

struct TabOrderTests {
    @Test func tabsChangingPlacesIsAReorder() {
        #expect(TabOrder.isReorder(from: ["a", "b", "c"], to: ["c", "a", "b"]))
        #expect(TabOrder.isReorder(from: ["a", "b", "c"], to: ["b", "a"]), "Even with one leaving")
    }

    @Test func tabsComingAndGoingIsNot() {
        #expect(!TabOrder.isReorder(from: ["a", "b", "c"], to: ["a", "c"]))
        #expect(!TabOrder.isReorder(from: ["a", "c"], to: ["a", "b", "c"]))
        #expect(!TabOrder.isReorder(from: ["a", "b"], to: ["a", "b"]))
    }
}
