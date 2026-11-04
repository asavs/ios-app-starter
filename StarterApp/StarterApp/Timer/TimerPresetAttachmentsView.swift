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
    @Environment(\.contentCoordinator) private var coordinator
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
                        .accessibilityIdentifier(Identifiers.Timer.Presets.attachmentsDone)
                }
                ToolbarItem(placement: .primaryAction) {
                    AttachmentPicker(model: picker)
                }
            }
            .attachmentPreview($selection, in: preset.attachments, store: StarterAttachments.store)
            .onChange(of: preset.attachments, save)
        }
    }

    /// The coordinator saves the record first and removes the file only when nothing else (a Library
    /// item) still owns it; a failed save leaves the file. Without a coordinator (a preview) the value
    /// just comes off the list.
    private func remove(_ attachment: Attachment) {
        guard let coordinator else {
            preset.attachments.removeAll { $0.id == attachment.id }
            return
        }
        do {
            try coordinator.removeAttachment(attachment, from: preset)
        } catch {
            assertionFailure("Removing an attachment failed: \(error)") // The record and the file are as they were.
        }
    }

    private func save() {
        try? context.save()
    }

    private func close() {
        dismiss()
    }
}
#endif
