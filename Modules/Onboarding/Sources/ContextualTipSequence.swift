import Foundation
import Observation
import TipKit

/// Tips shown one at a time in a fixed order, each anchored to its own view.
///
/// On iOS 18 and macOS 15 this is a TipKit `TipGroup(.ordered)`: the next tip appears once the
/// one before it is dismissed or invalidated. `TipGroup` does not exist on iOS 17, so there only
/// the first tip shows and the rest wait for a later OS; give the sequence its most useful tip
/// first. Hold it in `@State` and place each tip with `.contextualTip(_:in:)` (a popover) or
/// `ContextualTipView(_:in:)` (inline).
@MainActor @Observable
public final class ContextualTipSequence {
    public let tips: [ContextualTip]
    /// The `TipGroup` on systems that have one, kept untyped so the class itself stays on iOS 17.
    private let group: AnyObject?

    public init(_ tips: [ContextualTip]) {
        self.tips = tips
        if #available(iOS 18, macOS 15, *) {
            group = TipGroup(.ordered) {
                for tip in tips { tip }
            }
        } else {
            group = nil
        }
    }

    /// The tip on screen now, or `nil` when the sequence is done or waiting on its rules.
    public var currentTip: ContextualTip? {
        if #available(iOS 18, macOS 15, *), let group = group as? TipGroup {
            // The group hands tips back type-erased (`Tip` declares `AnyTip` as its eraser), so match by identity.
            guard let current = group.currentTip else { return nil }
            return tips.first { $0.id == current.id }
        }
        return tips.first
    }

    /// The current tip when its identifier is `id`, for a view that anchors only that tip.
    public func currentTip(id: String) -> ContextualTip? {
        currentTip.flatMap { $0.id == id ? $0 : nil }
    }

    /// Retires the tip with `id` because the user did what it suggests, letting the next one show.
    public func invalidate(_ id: String) {
        tips.first { $0.id == id }?.invalidate(reason: .actionPerformed)
    }
}
