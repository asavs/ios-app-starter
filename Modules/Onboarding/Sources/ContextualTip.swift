import SwiftUI
import TipKit

/// A TipKit tip described by values, so an app lists its tips as data instead of declaring a type
/// for each. Identity is `id`, which TipKit uses to remember whether the tip was seen or dismissed;
/// keep it stable across releases.
///
/// Every `ContextualTip` waits for `ContextualTips.isEligible`, which the onboarding gate turns
/// off while its flow is on screen, so a tip never lands on top of onboarding. Show one with
/// `.contextualTip(_:)`, several in order with `ContextualTipSequence`, and call `invalidate(reason:
/// .actionPerformed)` when the user does what the tip suggests.
public struct ContextualTip: Tip {
    /// Whether any contextual tip may show; see `ContextualTips.isEligible`. Not persisted: the gate
    /// sets it on every launch.
    @Parameter(.transient) static var isEligible: Bool = true

    public let id: String
    public let titleText: LocalizedStringResource
    public let messageText: LocalizedStringResource?
    public let systemImage: String?
    /// How many times TipKit shows the tip before treating it as seen.
    public let maxDisplayCount: Int

    /// Text parameters written as literals are looked up in the app's string catalog.
    public init(id: String, title: LocalizedStringResource, message: LocalizedStringResource? = nil, systemImage: String? = nil,
                maxDisplayCount: Int = 3) {
        self.id = id
        self.titleText = title
        self.messageText = message
        self.systemImage = systemImage
        self.maxDisplayCount = maxDisplayCount
    }

    public var title: Text { Text(titleText) }

    public var message: Text? { messageText.map { Text($0) } }

    public var image: Image? { systemImage.map { Image(systemName: $0) } }

    /// Never true: the rule that keeps `placeholder` hidden.
    @Parameter(.transient) static var showsPlaceholder: Bool = false

    /// Anchors a popover modifier while no real tip is current; it never shows.
    static let placeholder = ContextualTip(id: "contextualTip.placeholder", title: "")

    public var rules: [Rule] {
        if id == Self.placeholder.id {
            return [#Rule(Self.$showsPlaceholder) { $0 == true }]
        }
        return [#Rule(Self.$isEligible) { $0 == true }]
    }

    public var options: [any TipOption] {
        Tips.MaxDisplayCount(maxDisplayCount)
    }
}

public extension View {
    /// Anchors `tip` as a popover on this view, shown when TipKit's rules allow; `nil` shows nothing.
    @ViewBuilder func contextualTip(_ tip: ContextualTip?, arrowEdge: Edge = .top) -> some View {
        if #available(iOS 26, macOS 26, *) {
            popoverTip(tip, arrowEdge: arrowEdge)
        } else {
            // Before iOS 26 the SDK's optional-tip overloads are gated per release, and the compiler
            // picks the iOS 26 one; the generic overload for a concrete tip covers iOS 17 onward.
            // A placeholder that never shows stands in for `nil`, so the view keeps its identity
            // and its popover anchor when a sequence moves on to this tip.
            popoverTip(tip ?? .placeholder, arrowEdge: arrowEdge)
        }
    }

    /// Anchors the tip with `id` from `sequence` here; it shows only while it is the sequence's current tip.
    /// A popover anchored to a toolbar item does not appear on iOS 26; use `ContextualTipView` for those.
    func contextualTip(_ id: String, in sequence: ContextualTipSequence, arrowEdge: Edge = .top) -> some View {
        contextualTip(sequence.currentTip(id: id), arrowEdge: arrowEdge)
    }
}

/// A tip shown inline, in the layout, rather than as a popover: for tips about a control a popover
/// cannot reach, such as a toolbar button. Takes no room when the tip is not showing.
public struct ContextualTipView: View {
    private let tip: ContextualTip?

    public init(_ tip: ContextualTip?) {
        self.tip = tip
    }

    /// The tip with `id` from `sequence`, while it is the sequence's current tip.
    public init(_ id: String, in sequence: ContextualTipSequence) {
        self.init(sequence.currentTip(id: id))
    }

    public var body: some View {
        if let tip {
            // The generic initializer for a concrete tip is the one that exists on iOS 17.
            TipView<ContextualTip>(tip)
        }
    }
}

