import SwiftUI
#if canImport(SessionTimer) && canImport(Database) && canImport(Attachments)
import Attachments
import SwiftData
import Theme

/// A preset's attachments: a photo of the drill, the plan as a PDF, a link to the source. The
/// Add menu picks from Photos, the camera, Files or a typed link; a tap previews; Remove is on
/// the cell. The files live in `StarterAttachments.store`; the preset keeps the values.
/// Accessibility identifiers: `timer.presets.attachments.done`, plus the module's.
struct TimerPresetAttachmentsView: View {
    @Bindable var preset: TimerPreset
    @State private var picker: AttachmentPickerModel
    @State private var selection: Attachment?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    init(preset: TimerPreset) {
        self.preset = preset
        _picker = State(initialValue: AttachmentPickerModel(store: StarterAttachments.store) { added in
            preset.attachments.append(contentsOf: added)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.large) {
                    if preset.attachments.isEmpty {
                        EmptyStateView(systemImage: "paperclip", title: "No attachments yet",
                                       message: "Add a photo, a file or a link that goes with this preset.")
                    } else {
                        AttachmentGrid(preset.attachments, store: StarterAttachments.store, selection: $selection,
                                       onRemove: remove)
                    }
                    ForEach(preset.attachments.filter(\.isLink)) { link in
                        LinkPreview(link, store: StarterAttachments.store)
                    }
                }
                .padding()
            }
            .background(theme.colors.background)
            .navigationTitle(preset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                        .accessibilityIdentifier("timer.presets.attachments.done")
                }
                ToolbarItem(placement: .primaryAction) {
                    AttachmentPicker(model: picker)
                }
            }
            .attachmentPreview($selection, in: preset.attachments, store: StarterAttachments.store)
            .onChange(of: preset.attachments, save)
        }
    }

    private func remove(_ attachment: Attachment) {
        preset.attachments.removeAll { $0.id == attachment.id }
        Task { try? await StarterAttachments.store.remove(attachment) }
    }

    private func save() {
        try? context.save()
    }

    private func close() {
        dismiss()
    }
}
#endif
