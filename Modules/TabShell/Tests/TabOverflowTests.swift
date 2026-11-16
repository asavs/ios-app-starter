import Testing
@testable import TabShell

struct TabOverflowTests {
    @Test func aCompactBarHoldsFive() {
        let five = ["a", "b", "c", "d", "e"]
        #expect(TabOverflow.split(five, compact: true) == (five, []))
    }

    @Test func sixOrMoreLeaveFourAndMore() {
        let split = TabOverflow.split(["a", "b", "c", "d", "e", "f", "g"], compact: true)
        #expect(split.bar == ["a", "b", "c", "d"])
        #expect(split.more == ["e", "f", "g"], "In order, after the bar's")
    }

    @Test func aRegularBarHoldsEveryTab() {
        let seven = ["a", "b", "c", "d", "e", "f", "g"]
        #expect(TabOverflow.split(seven, compact: false) == (seven, []))
    }
}
