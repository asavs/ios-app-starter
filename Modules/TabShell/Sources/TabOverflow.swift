/// How many tabs a bar shows before the rest move into More.
///
/// A compact bar (an iPhone, or an iPad window narrowed to compact width) shows up to five; with more
/// than five, it shows the first four and a More tab with the rest, as the system does. The shell
/// lists them itself rather than leaving them to the system's More: a SwiftUI destination opened from
/// the system's list never reached the tab view's selection, so a relaunch forgot it, and its own
/// navigation stack drew a second bar under More's (iOS 27.0, ios-125.9).
enum TabOverflow {
    static let compactLimit = 5

    /// The tabs in the bar and the tabs in More, in order.
    static func split<T>(_ tabs: [T], compact: Bool) -> (bar: [T], more: [T]) {
        guard compact, tabs.count > compactLimit else { return (tabs, []) }
        return (Array(tabs.prefix(compactLimit - 1)), Array(tabs.dropFirst(compactLimit - 1)))
    }
}
