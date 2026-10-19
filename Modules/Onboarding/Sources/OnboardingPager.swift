import Foundation

/// Position within a page sequence: which page is showing and whether the next step finishes.
///
/// Pure state so the flow's rules are testable without a view: `advance()` moves forward until
/// the last page and reports when the flow is finished; `index` never leaves `0..<pageCount`.
public struct OnboardingPager: Equatable, Sendable {
    public let pageCount: Int
    public private(set) var index: Int

    public init(pageCount: Int, index: Int = 0) {
        self.pageCount = max(pageCount, 0)
        self.index = min(max(index, 0), max(self.pageCount - 1, 0))
    }

    /// `true` on the final page, or when there are no pages at all.
    public var isLast: Bool { index >= pageCount - 1 }

    /// Fraction of the flow seen so far, from `1/pageCount` on the first page to `1` on the last.
    public var progress: Double {
        pageCount == 0 ? 1 : Double(index + 1) / Double(pageCount)
    }

    /// Moves to the next page. Returns `true` when the flow has finished instead.
    @discardableResult
    public mutating func advance() -> Bool {
        guard !isLast else { return true }
        index += 1
        return false
    }

    /// Moves to a page the user selected directly (a swipe), clamped to the valid range.
    public mutating func select(_ newIndex: Int) {
        index = min(max(newIndex, 0), max(pageCount - 1, 0))
    }
}
