import Foundation
#if canImport(TabShell)

/// The app's destinations, one per feature, by stable identifier. The raw value is what the tab
/// selection stores, what a deep link names (`starterapp://timer`) and what a UI test looks up, so
/// it never changes when a label does: `welcome` stays `welcome` while its tab reads Home.
///
/// Every case exists in every build; `StarterFeature` says which are available in this one. The app
/// builder adds a case here, a descriptor in `StarterFeature.all` and a screen in `StarterTabsView`.
enum StarterTab: String, CaseIterable {
    case welcome
    case library
    case timer
    case settings
}
#endif
