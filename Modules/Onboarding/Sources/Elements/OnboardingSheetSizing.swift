import SwiftUI

/// Asks for the taller page-sized sheet at accessibility text sizes. On iPad the default form sheet
/// is about half the screen high, which leaves a few lines of a page between Skip, the page dots and
/// Continue; the page size gives the flow most of the screen. On iPhone a sheet is full height
/// either way, and before iOS 18 the system keeps its default and the page scrolls.
struct OnboardingSheetSizing: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *), dynamicTypeSize.isAccessibilitySize {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}
