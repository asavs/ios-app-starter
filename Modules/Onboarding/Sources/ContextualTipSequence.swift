import Foundation
import Observation
import TipKit

/// Tips shown one at a time in a fixed order, each anchored to its own view.
///
/// On iOS 26 and macOS 26 this is a TipKit `TipGroup(.ordered)`: the next tip appears once the
/// one before it is dismissed or invalidated. Earlier systems follow each tip's own status
/// instead: `TipGroup` does not exist on iOS 17, and on iOS 18 its next tip never appeared in the
/// compatibility lanes. Hold the sequence in `@State` and place each tip with `.contextualTip(_:in:)`
/// (a popover) or `ContextualTipView(_:in:)` (inline).
@MainActor @Observable
public final class ContextualTipSequence {
    public let tips: [ContextualTip]
    /// The `TipGroup` on systems that use one, kept untyped so the class itself stays on iOS 17.
    private let group: AnyObject?
    /// Tips already closed or retired, on systems without a usable `TipGroup`.
    private var invalidated: Set<String> = []
    @ObservationIgnored nonisolated(unsafe) private var watchers: [Task<Void, Never>] = []

    public init(_ tips: [ContextualTip]) {
        self.tips = tips
        if #available(iOS 26, macOS 26, *) {
            group = TipGroup(.ordered) {
                for tip in tips { tip }
            }
        } else {
            group = nil
            watchers = tips.map { tip in
                Task { [weak self] in
                    for await status in tip.statusUpdates {
                        if case .invalidated = status {
                            self?.invalidated.insert(tip.id)
                        }
                    }
                }
            }
        }
    }

    deinit {
        watchers.forEach { $0.cancel() }
    }

    /// The tip on screen now, or `nil` when the sequence is done or waiting on its rules.
    public var currentTip: ContextualTip? {
        if #available(iOS 26, macOS 26, *), let group = group as? TipGroup {
            // The group hands tips back type-erased (`Tip` declares `AnyTip` as its eraser), so match by identity.
            guard let current = group.currentTip else { return nil }
            return tips.first { $0.id == current.id }
        }
        return Self.firstTip(of: tips, skipping: invalidated)
    }

    /// The current tip when its identifier is `id`, for a view that anchors only that tip.
    public func currentTip(id: String) -> ContextualTip? {
        currentTip.flatMap { $0.id == id ? $0 : nil }
    }

    /// Retires the tip with `id` because the user did what it suggests, letting the next one show.
    public func invalidate(_ id: String) {
        tips.first { $0.id == id }?.invalidate(reason: .actionPerformed)
        if group == nil {
            invalidated.insert(id)
        }
    }

    /// The order used without a `TipGroup`: the first tip not yet closed or retired.
    nonisolated static func firstTip(of tips: [ContextualTip], skipping invalidated: Set<String>) -> ContextualTip? {
        tips.first { !invalidated.contains($0.id) }
    }
}
