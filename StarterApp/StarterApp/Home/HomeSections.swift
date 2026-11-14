import SwiftUI
#if canImport(TabShell)
import Theme

/// Home's content in a build with tabs: the newest notes and Library items, then a shortcut to each
/// other chosen tab. A feature's section shows only while its tab is chosen and its modules are in
/// the build, so Home never offers what the tab bar doesn't. Everything shown comes from the
/// features' own stores; nothing is counted or made up here.
struct HomeSections: View {
    @State private var choices = FeatureChoices.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.extraLarge) {
#if canImport(Database)
            if choices.chosen.contains(.notes) {
                RecentNotesSection()
            }
#endif
#if canImport(Database) && canImport(Attachments)
            if choices.chosen.contains(.library) {
                RecentLibrarySection()
            }
#endif
            HomeShortcuts(features: choices.chosen.filter { $0 != .welcome }.map(StarterFeature.feature))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
