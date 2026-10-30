import SwiftUI
import Testing
@testable import TimerRing

struct TimerRingTests {
    @Test(arguments: [
        (Duration.seconds(20), Duration.seconds(20)),
        (.milliseconds(19_001), .seconds(20)), // Rounds up, so the first second still reads 0:20.
        (.milliseconds(1), .seconds(1)),
        (.zero, .zero),
        (.seconds(-3), .zero),
    ])
    func displaysWholeSecondsRoundedUp(remaining: Duration, shown: Duration) {
        #expect(TimerRing.displayed(remaining) == shown)
    }

    @Test(arguments: [(-1.0, 0.0), (0, 0), (0.5, 0.5), (1, 1), (2, 1), (.nan, 0), (.infinity, 0)])
    func clampsTheFraction(_ fraction: Double, drawn: Double) {
        // Out-of-range and non-finite fractions are clamped rather than drawing a broken ring.
        #expect(TimerRing(fractionRemaining: fraction, title: "Work", remaining: .seconds(5)).fractionRemaining == drawn)
    }
}
