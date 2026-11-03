import Foundation
#if canImport(TabShell)
import TabShell

/// What the app can show as a tab: a stable identity, how the tab reads, whether this build has
/// the feature, and whether a fresh install shows it. The template keeps its features here, in the
/// host, until a second app needs the same registry.
///
/// Availability is a build fact (`#if canImport`); a person's choice of tabs is `FeatureChoices`.
/// Hiding a tab never removes a module or its data; removing a module makes the feature
/// unavailable, and a stored choice naming it is simply skipped until it is back.
struct StarterFeature: Identifiable, Hashable {
    // Identity is the stable id: the localized titles aren't hashable, and two descriptors for one tab are one feature.
    static func == (lhs: StarterFeature, rhs: StarterFeature) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: StarterTab
    /// The tab's label.
    let title: LocalizedStringResource
    /// One sentence for a chooser: what the person does there.
    let summary: LocalizedStringResource
    let systemImage: String
    /// Compiled into this build.
    let isAvailable: Bool
    /// Shown by a fresh install that skipped the choice, or by an installation from before choices existed.
    let isDefault: Bool
    /// Always reachable: appended to any choice that leaves it out, so settings and local data stay in reach.
    let isRequired: Bool

    /// Every feature the template knows, in its default order. Order here is the default tab order.
    static let all: [StarterFeature] = [
        StarterFeature(id: .welcome, title: "Home", summary: "Recent content and shortcuts to the features you use.",
                       systemImage: "house", isAvailable: true, isDefault: true, isRequired: false),
        StarterFeature(id: .timer, title: "Timer", summary: "Run interval sessions, save plans and follow them from the Lock Screen.",
                       systemImage: "timer", isAvailable: hasTimer, isDefault: true, isRequired: false),
        StarterFeature(id: .settings, title: "Settings", summary: "Appearance, sounds, privacy and your local data.",
                       systemImage: "gearshape", isAvailable: hasSettings, isDefault: true, isRequired: true),
    ]

    /// The features this build can show, in default order.
    static var available: [StarterFeature] { all.filter(\.isAvailable) }

    static func feature(_ id: StarterTab) -> StarterFeature {
        all.first { $0.id == id }! // `all` lists every case; the test `everyTabHasAFeature` holds it to that.
    }

    /// The shell's descriptor for this feature.
    var item: TabItem<StarterTab> {
        TabItem(id: id, title: title, systemImage: systemImage)
    }

    private static var hasTimer: Bool {
#if canImport(SessionTimer) && canImport(TimerRing)
        true
#else
        false
#endif
    }

    private static var hasSettings: Bool {
#if canImport(Settings)
        true
#else
        false
#endif
    }
}
#endif
