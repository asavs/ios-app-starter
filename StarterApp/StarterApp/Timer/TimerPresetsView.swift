import SwiftUI
#if canImport(SessionTimer) && canImport(Database)
import SwiftData
import Theme

/// Saved plans: tap one to load it, swipe to delete, or save the current plan under a name.
/// Accessibility identifiers: `timer.presets.save`, `timer.presets.name`, `timer.presets.done`,
/// `timer.presets.row.<name>`.
struct TimerPresetsView: View {
    let model: TimerScreenModel
    @Query(sort: \TimerPreset.createdAt) private var presets: [TimerPreset]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(presets) { preset in
                    Button {
                        load(preset)
                    } label: {
                        TimerPresetRow(preset: preset)
                    }
                    .disabled(model.canChangePlan == false)
                    .accessibilityIdentifier("timer.presets.row.\(preset.name)")
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if presets.isEmpty {
                    EmptyStateView(systemImage: "bookmark", title: "No presets yet",
                                   message: "Save the current plan to reuse it later.")
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                        .accessibilityIdentifier("timer.presets.done")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save Current", systemImage: "plus", action: askForName)
                        .accessibilityIdentifier("timer.presets.save")
                }
            }
            .alert("Save the current plan", isPresented: $isNaming) {
                TextField("Preset name", text: $newName)
                    .accessibilityIdentifier("timer.presets.name")
                Button("Save", action: save)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func load(_ preset: TimerPreset) {
        model.apply(preset)
        dismiss()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(presets[index]) }
        try? context.save()
    }

    private func askForName() {
        newName = ""
        isNaming = true
    }

    private func save() {
        context.insert(model.preset(named: newName.trimmingCharacters(in: .whitespaces)))
        try? context.save()
    }

    private func close() {
        dismiss()
    }
}
#endif
