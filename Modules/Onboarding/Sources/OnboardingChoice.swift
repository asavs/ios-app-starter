import Foundation

/// One question with a fixed set of answers, asked as an onboarding step.
///
/// Ask only what changes the product, such as which content to show first or which goal to plan
/// for; a question whose answer the app ignores is friction. The flow reports the current answer
/// to `onAnswer` each time it changes, as option identifiers in option order, so the host has it
/// whether the user continues, swipes on or skips the rest of the flow. With `requiresAnswer` the
/// Continue button stays disabled, and the flow will not page past, until something is picked.
public struct OnboardingChoice: Identifiable, Sendable {
    public struct Option: Identifiable, Hashable, Sendable {
        public var id: String
        public var title: String
        /// SF Symbol name shown before the title; `nil` shows none.
        public var systemImage: String?

        /// - Parameter id: Stable identity reported to the host; defaults to the title.
        public init(id: String? = nil, title: String, systemImage: String? = nil) {
            self.id = id ?? title
            self.title = title
            self.systemImage = systemImage
        }
    }

    public enum Mode: Sendable {
        /// Exactly one answer; picking another replaces it.
        case single
        /// Any number of answers; picking one toggles it.
        case multiple
    }

    public var id: String
    public var title: String
    /// A line under the question; `nil` hides it.
    public var message: String?
    public var options: [Option]
    public var mode: Mode
    public var requiresAnswer: Bool
    /// Options picked when the step first appears.
    public var initialSelection: Set<String>
    /// Receives the answer, as option identifiers in option order, each time it changes.
    public var onAnswer: @MainActor @Sendable ([String]) -> Void

    public init(id: String, title: String, message: String? = nil, options: [Option], mode: Mode = .single,
                requiresAnswer: Bool = false, initialSelection: Set<String> = [],
                onAnswer: @escaping @MainActor @Sendable ([String]) -> Void = { _ in }) {
        self.id = id
        self.title = title
        self.message = message
        self.options = options
        self.mode = mode
        self.requiresAnswer = requiresAnswer
        self.onAnswer = onAnswer
        self.initialSelection = []
        self.initialSelection = valid(initialSelection)
    }

    /// The selection after the user taps `optionID`. A single choice keeps a tapped answer selected
    /// rather than clearing it, like a radio button; unknown identifiers change nothing.
    public func selection(_ selection: Set<String>, tapping optionID: String) -> Set<String> {
        guard options.contains(where: { $0.id == optionID }) else { return selection }
        switch mode {
        case .single:
            return [optionID]
        case .multiple:
            return selection.symmetricDifference([optionID])
        }
    }

    /// The selection as reported to the host: known identifiers only, in option order.
    public func answer(for selection: Set<String>) -> [String] {
        options.map(\.id).filter(selection.contains)
    }

    /// Whether the flow may move past this step with `selection`.
    public func canContinue(with selection: Set<String>) -> Bool {
        !requiresAnswer || !answer(for: selection).isEmpty
    }

    /// `selection` limited to known options, and to the first of them for a single choice.
    private func valid(_ selection: Set<String>) -> Set<String> {
        let known = answer(for: selection)
        return Set(mode == .single ? Array(known.prefix(1)) : known)
    }
}
