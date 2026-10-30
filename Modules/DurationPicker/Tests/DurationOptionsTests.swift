import Foundation
import Testing
@testable import DurationPicker

struct DurationOptionsTests {
    private let options = DurationOptions(range: .seconds(5) ... .seconds(600), step: .seconds(5))

    @Test func wheelsCoverTheRange() {
        #expect(options.hours.isEmpty, "Under an hour, there's no hours wheel")
        #expect(options.minutes == Array(0...10))
        #expect(options.seconds == [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55])
    }

    @Test func theDefaultMatchesTheClockApp() {
        let clock = DurationOptions(range: .seconds(1) ... .seconds(DurationOptions.longest), step: .seconds(1))
        #expect(clock.hours == Array(0...23))
        #expect(clock.minutes == Array(0...59))
        #expect(clock.seconds == Array(0...59))
    }

    @Test(arguments: [
        (Duration.seconds(20), Duration.seconds(20)),
        (.seconds(22), .seconds(20)), // Nearest step.
        (.seconds(23), .seconds(25)),
        (.zero, .seconds(5)), // Below the range.
        (.seconds(2), .seconds(5)),
        (.seconds(9000), .seconds(600)), // Above it.
        (.milliseconds(20_400), .seconds(20)),
    ])
    func clampsToTheRangeAndStep(value: Duration, expected: Duration) {
        #expect(options.clamped(value) == expected)
    }

    @Test func splitsAndCombines() {
        let clock = DurationOptions(range: .zero ... .seconds(DurationOptions.longest), step: .seconds(1))
        #expect(clock.split(.seconds(3725)) == .init(hours: 1, minutes: 2, seconds: 5))
        #expect(clock.combined(.init(hours: 1, minutes: 2, seconds: 5)) == .seconds(3725))
        #expect(options.combined(.init(hours: 0, minutes: 2, seconds: 30)) == .seconds(150))
        #expect(options.combined(.init(hours: 0, minutes: 0, seconds: 0)) == .seconds(5), "Zero is below the range")
        #expect(options.combined(.init(hours: 0, minutes: 10, seconds: 30)) == .seconds(600), "Past the range")
    }

    @Test func aStepThatDoesntDivideAMinuteFallsBackToOneSecond() {
        #expect(DurationOptions(range: .zero ... .seconds(60), step: .seconds(7)).step == 1)
        #expect(DurationOptions(range: .zero ... .seconds(60), step: .zero).step == 1)
    }

    @Test func rangesAreKeptWithinTheClockLimit() {
        let wide = DurationOptions(range: .seconds(-30) ... .seconds(48 * 3600), step: .seconds(1))
        #expect(wide.range == .zero ... .seconds(DurationOptions.longest))
        #expect(wide.hours.last == 23)
    }

    @Test func aRangeOffTheStepStaysInside() {
        let odd = DurationOptions(range: .seconds(3) ... .seconds(58), step: .seconds(5))
        #expect(odd.clamped(.zero) == .seconds(5))
        #expect(odd.clamped(.seconds(99)) == .seconds(55))
    }
}
