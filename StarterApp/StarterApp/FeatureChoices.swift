import Foundation
import Observation
#if canImport(TabShell)

/// The tabs a person chose, in their order: the host's state behind the shell. One per scene root.
///
/// Stored as the feature identifiers joined with commas under `tabs.chosen`, apart from the selected
/// tab (`tabs.selected`), so choosing tabs and switching tabs never overwrite each other. A string,
/// not an array, so a UI test can seed it through the argument domain (`-tabs.chosen settings,welcome`).
///
/// Reading never writes: opening the app, or replaying onboarding, leaves a stored choice as it is.
/// Only `set`, `reveal` and `open(link:)` store.
@MainActor @Observable
final class FeatureChoices {
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
