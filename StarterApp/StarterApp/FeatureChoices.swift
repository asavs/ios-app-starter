import Observation
import SwiftUI // Also brings Foundation, and `Array.move(fromOffsets:toOffset:)` for a list's reordering.
#if canImport(TabShell)

/// The tabs a person chose, in their order: the state behind the shell and Settings' chooser. One for
/// the app (`shared`): a choice is the app's, while the selected tab is each scene's.
///
/// Stored as the feature identifiers joined with commas under `tabs.chosen`, apart from the selected
/// tab (`tabs.selected`), so choosing tabs and switching tabs never overwrite each other. A string,
/// not an array, so a UI test can seed it through the argument domain (`-tabs.chosen settings,welcome`).
///
/// Reading never writes: opening the app, or replaying onboarding, leaves a stored choice as it is.
/// Only the methods that change the choice store.
@MainActor @Observable
final class FeatureChoices {
    static let shared = FeatureChoices()
    static let storageKey = "tabs.chosen"

    /// The chosen features, normalized: available, unique, Settings included, never empty.
    private(set) var chosen: [StarterTab]
    private let defaults: UserDefaults
    private let features: [StarterFeature]

    /// - Parameters:
    ///   - defaults: Where the choice is stored; the app's store, or an isolated suite in tests.
    ///   - features: The registry, `StarterFeature.all` in the app; tests pass their own availability.
    init(defaults: UserDefaults = StarterDefaults.store, features: [StarterFeature] = StarterFeature.all) {
        self.defaults = defaults
        self.features = features
        chosen = Self.normalize(Self.stored(in: defaults), features: features)
    }

    /// The stored identifiers, or nil when nothing was ever stored.
    static func stored(in defaults: UserDefaults) -> [String]? {
        defaults.string(forKey: storageKey)?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// What a stored or requested list means in this build:
    /// - unknown, unavailable and repeated identifiers are dropped (the first occurrence counts);
    /// - nothing stored, or nothing valid left, means the configuration's defaults, so an
    ///   installation from before choices existed, or a choice whose every feature went away, still
    ///   shows the app rather than an empty shell;
    /// - required features are appended when missing, so Settings stays reachable;
    /// - a stored list gains nothing else: a feature added to the app later waits to be chosen.
    static func normalize(_ stored: [String]?, features: [StarterFeature]) -> [StarterTab] {
        let available = features.filter(\.isAvailable)
        var result: [StarterTab] = []
        for raw in stored ?? [] {
            guard let feature = available.first(where: { $0.id.rawValue == raw }), !result.contains(feature.id) else { continue }
            result.append(feature.id)
        }
        if result.isEmpty {
            result = available.filter(\.isDefault).map(\.id)
        }
        for feature in available where feature.isRequired && !result.contains(feature.id) {
            result.append(feature.id)
        }
        return result
    }

    /// The tab a shell starts on and falls back to when the selected one leaves the list: Home when
    /// chosen, otherwise the first chosen tab.
    var defaultTab: StarterTab {
        chosen.contains(.welcome) ? .welcome : chosen[0]
    }

    /// The features this build has that aren't among the chosen tabs, in default order.
    var hidden: [StarterFeature] {
        features.filter { $0.isAvailable && !chosen.contains($0.id) }
    }

    /// Replace the choice: a chooser's result, in its order. Normalized and stored.
    func set(_ tabs: [StarterTab]) {
        chosen = Self.normalize(tabs.map(\.rawValue), features: features)
        store()
    }

    /// Add an available feature the person had left out, at the end. Stored; nothing happens for a
    /// feature already chosen or not in this build.
    func reveal(_ tab: StarterTab) {
        guard !chosen.contains(tab), features.contains(where: { $0.id == tab && $0.isAvailable }) else { return }
        chosen.append(tab)
        store()
    }

    /// Add an available feature where the default order puts it, ahead of the first chosen tab that
    /// comes after it there. Onboarding's step uses this, so turning a tab off and on again leaves the
    /// order as it was. Stored; nothing happens for a feature already chosen or not in this build.
    func include(_ tab: StarterTab) {
        guard !chosen.contains(tab), features.contains(where: { $0.id == tab && $0.isAvailable }) else { return }
        let order = features.map(\.id)
        let rank = order.firstIndex(of: tab) ?? order.count
        let index = chosen.firstIndex { (order.firstIndex(of: $0) ?? order.count) > rank } ?? chosen.count
        chosen.insert(tab, at: index)
        store()
    }

    /// Take a tab out of the choice. Only navigation changes: the feature's content and any running
    /// session stay where they are. Nothing happens for a required feature.
    func hide(_ tab: StarterTab) {
        guard features.first(where: { $0.id == tab })?.isRequired == false else { return }
        set(chosen.filter { $0 != tab })
    }

    /// Reorder as a list's `onMove` reports it.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = chosen
        reordered.move(fromOffsets: source, toOffset: destination)
        set(reordered)
    }

    /// Move a tab by places, for the Move Up and Move Down accessibility actions. A move past either
    /// end does nothing.
    func move(_ tab: StarterTab, by offset: Int) {
        guard let index = chosen.firstIndex(of: tab), chosen.indices.contains(index + offset) else { return }
        var reordered = chosen
        reordered.swapAt(index, index + offset)
        set(reordered)
    }

    /// Read the stored choice again, after Erase Local Data removed it: the tabs go back to the
    /// configuration's defaults at once, and nothing is stored.
    func reload() {
        chosen = Self.normalize(Self.stored(in: defaults), features: features)
    }

    /// What a validated deep link to a feature should do.
    enum LinkOutcome: Equatable {
        /// The tab is chosen: select it.
        case select(StarterTab)
        /// The feature is in this build but not among the chosen tabs: it has been revealed; select it.
        case revealed(StarterTab)
        /// The feature exists but this build doesn't include it: say so rather than show nothing.
        case unavailable(StarterTab)
        /// Not a feature at all.
        case ignore
    }

    /// Apply the deep-link policy to a tab name the host has already validated (`DeepLink.tab(in:)`):
    /// a hidden available feature is revealed and stored, so the link's destination stays reachable
    /// afterwards. Live Activity and widget links come through the same path.
    func open(link raw: String) -> LinkOutcome {
        guard let tab = StarterTab(rawValue: raw), let feature = features.first(where: { $0.id == tab }) else { return .ignore }
        guard feature.isAvailable else { return .unavailable(tab) }
        if chosen.contains(tab) { return .select(tab) }
        reveal(tab)
        return .revealed(tab)
    }

    private func store() {
        defaults.set(chosen.map(\.rawValue).joined(separator: ","), forKey: Self.storageKey)
    }
}
#endif
