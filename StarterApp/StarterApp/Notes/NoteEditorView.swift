import SwiftUI
#if canImport(Database)
import SwiftData
import Theme

/// One note: a title field and a text editor over a draft, with Save and Done. Save writes the
/// draft and keeps the editor open; Done leaves, asking what to do with unsaved changes first. A
/// failed save says so and keeps the text. With Attachments, a saved note can refer to Library items.
/// Accessibility identifiers: `notes.editor.title`, `.body`, `.save`, `.done`, `.discard`, `.retry`.
struct NoteEditorView: View {
    @State private var model: NoteEditorModel
    @State private var isLeaving = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var bodyMinimumHeight = 220.0

    init(model: NoteEditorModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                TextField("Title", text: $model.draft.title)
                    .font(theme.typography.headline)
                    .accessibilityIdentifier(Identifiers.Notes.Editor.title)
                TextEditor(text: $model.draft.body)
                    .font(theme.typography.body)
                    .frame(minHeight: bodyMinimumHeight)
                    .accessibilityLabel(Text("Note"))
                    .accessibilityIdentifier(Identifiers.Notes.Editor.body)
            } footer: {
                if model.isDirty {
                    Text("Unsaved changes")
                }
            }
#if canImport(Attachments)
            NoteReferencesSection(noteID: model.draft.id, isSaved: model.draft.isSaved)
#endif
        }
        .navigationTitle(Text(verbatim: model.draft.displayTitle ?? String(localized: "New Note")))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar { toolbar }
        .alert("Couldn't Save", isPresented: $model.hasFailure, actions: failureActions, message: failureMessage)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done", action: leave)
                .accessibilityIdentifier(Identifiers.Notes.Editor.done)
                // On the button, so a dialog shown as a popover (iOS 27) points at it.
                .confirmationDialog("You have unsaved changes", isPresented: $isLeaving, titleVisibility: .visible,
                                    actions: leavingActions)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { model.save() }
                .disabled(!model.canSave)
                .accessibilityIdentifier(Identifiers.Notes.Editor.save)
        }
    }

    @ViewBuilder
    private func leavingActions() -> some View {
        Button("Save") { saveAndLeave() }
        Button("Discard Changes", role: .destructive) { discardAndLeave() }
            .accessibilityIdentifier(Identifiers.Notes.Editor.discard)
        Button("Keep Editing", role: .cancel) {}
    }

    @ViewBuilder
    private func failureActions() -> some View {
        Button("Try Again") { model.save() }
            .accessibilityIdentifier(Identifiers.Notes.Editor.retry)
        Button("Discard Changes", role: .destructive) { discardAndLeave() }
        Button("Keep Editing", role: .cancel) {}
    }

    private func failureMessage() -> Text {
        Text(verbatim: model.failure ?? "")
    }

    /// Done: leave at once when nothing changed (a blank new note is forgotten), otherwise ask.
    private func leave() {
        if model.isDirty {
            isLeaving = true
        } else {
            if !model.draft.isSaved { model.discard() }
            dismiss()
        }
    }

    private func saveAndLeave() {
        if model.save() { dismiss() } // A failure keeps the editor open with its alert.
    }

    private func discardAndLeave() {
        model.discard()
        dismiss()
    }
}
#endif
