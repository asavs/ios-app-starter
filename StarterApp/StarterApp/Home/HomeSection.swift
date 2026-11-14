import SwiftUI
#if canImport(TabShell)
import Theme

/// One of Home's sections: a header naming it, with See All when a tab holds the rest, over its
/// rows on a card. The header carries `home.section.<tab>`.
struct HomeSection<Content: View>: View {
    let tab: StarterTab
    let title: LocalizedStringResource
    /// The tab See All opens; nil for no See All.
    var seeAll: StarterTab?
    @ViewBuilder let content: Content
    @Environment(\.openTab) private var openTab
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(Identifiers.Home.section(tab.rawValue))
                Spacer(minLength: theme.spacing.small)
                if let seeAll {
                    Button("See All") { openTab(seeAll) }
                        .font(theme.typography.body)
                        // Two sections can offer See All: VoiceOver and Voice Control name the tab it opens.
                        .accessibilityLabel(Text("See All \(String(localized: StarterFeature.feature(seeAll).title))"))
                        .accessibilityInputLabels([Text("See All \(String(localized: StarterFeature.feature(seeAll).title))"), Text("See All")])
                        .accessibilityIdentifier(Identifiers.Home.seeAll(seeAll.rawValue))
                }
            }
            ThemedCard {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
#endif
