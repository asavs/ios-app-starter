import SwiftUI
#if canImport(TabShell)

/// Settings' chooser: which features show as tabs, and in what order. Changes apply as they're made;
/// the tab bar is right there, so there is nothing to save.
///
/// The list stays in editing mode for its drag handles. Hiding uses a button of its own rather than
/// the list's delete control, because nothing is deleted.
struct TabChoicesView: View {
    @State private var choices = FeatureChoices.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        List {
            Section {
                ForEach(choices.chosen, id: \.self) { tab in
                    shownRow(StarterFeature.feature(tab))
                }
                .onMove { source, destination in
                    let moved = source.first.map { choices.chosen[$0] }
                    choices.move(fromOffsets: source, toOffset: destination)
                    if let moved { announcePosition(of: moved) }
                }
            } header: {
                Text("Shown")
            } footer: {
                Text("Drag to change the order. Settings always stays, so you can come back here.")
            }
            let hidden = choices.hidden
            if !hidden.isEmpty {
                Section {
                    ForEach(hidden) { feature in
                        TabChoiceRow(feature: feature, control: .show { show(feature) })
                    }
                } header: {
                    Text("Hidden")
                } footer: {
                    Text("Hidden tabs keep their content, and anything running keeps going.")
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(Text("Tabs"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shownRow(_ feature: StarterFeature) -> some View {
        let index = choices.chosen.firstIndex(of: feature.id) ?? 0
        return TabChoiceRow(feature: feature,
                            control: feature.isRequired ? .alwaysShown : .hide { hide(feature) },
                            moveUp: index > 0 ? { move(feature, by: -1) } : nil,
                            moveDown: index < choices.chosen.count - 1 ? { move(feature, by: 1) } : nil)
    }

    private func hide(_ feature: StarterFeature) {
        withAnimation(reduceMotion ? nil : .default) { choices.hide(feature.id) }
        AccessibilityNotification.Announcement(String(localized: "\(String(localized: feature.title)) hidden")).post()
    }

    private func show(_ feature: StarterFeature) {
        withAnimation(reduceMotion ? nil : .default) { choices.reveal(feature.id) }
        AccessibilityNotification.Announcement(String(localized: "\(String(localized: feature.title)) shown")).post()
    }

    private func move(_ feature: StarterFeature, by offset: Int) {
        withAnimation(reduceMotion ? nil : .default) { choices.move(feature.id, by: offset) }
        announcePosition(of: feature.id)
    }

    /// A move has no visible text of its own, so VoiceOver gets the row's new place.
    private func announcePosition(of tab: StarterTab) {
        guard let index = choices.chosen.firstIndex(of: tab) else { return }
        let title = String(localized: StarterFeature.feature(tab).title)
        AccessibilityNotification.Announcement(String(localized: "\(title) moved to position \(index + 1) of \(choices.chosen.count)")).post()
    }
}
#endif
