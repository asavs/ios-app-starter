import SwiftUI

/// Goes back from a tab opened from More to More's list. The shell puts it in the environment of
/// that tab's destination only; elsewhere it's nil. `tabShellMoreButton()` draws the button for it.
public struct ShowMoreListAction {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    public func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    /// Non-nil inside a destination the person opened from More.
    @Entry public var showMoreList: ShowMoreListAction?
}
