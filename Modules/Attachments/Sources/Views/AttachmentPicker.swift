import PhotosUI
import SwiftUI
import Theme

/// The Add menu: Photos, Camera, Files and Link, each presenting its system picker, with the
/// model doing the copying. Accessibility identifiers: `attachments.add`, `attachments.add.photos`,
/// `attachments.add.camera`, `attachments.add.files`, `attachments.add.link`, `attachments.link.field`,
/// `attachments.link.add`.
public struct AttachmentPicker: View {
    @Bindable private var model: AttachmentPickerModel

    public init(model: AttachmentPickerModel) {
        self.model = model
    }

    public var body: some View {
        let available = model.availableSources
        Menu {
            if available.contains(.photos) {
                Button(action: model.choosePhotos) {
                    Label { Text("Photos", bundle: .module) } icon: { Image(systemName: "photo.on.rectangle") }
                }
                .accessibilityIdentifier("attachments.add.photos")
            }
            if available.contains(.camera) {
                Button(action: model.chooseCamera) {
                    Label { Text("Camera", bundle: .module) } icon: { Image(systemName: "camera") }
                }
                .accessibilityIdentifier("attachments.add.camera")
            }
            if available.contains(.files) {
                Button(action: model.chooseFiles) {
                    Label { Text("Files", bundle: .module) } icon: { Image(systemName: "folder") }
                }
                .accessibilityIdentifier("attachments.add.files")
            }
            if available.contains(.link) {
                Button(action: model.chooseLink) {
                    Label { Text("Link", bundle: .module) } icon: { Image(systemName: "link") }
                }
                .accessibilityIdentifier("attachments.add.link")
            }
        } label: {
            Label { Text("Add Attachment", bundle: .module) } icon: {
                if model.importsInProgress > 0 {
                    ProgressView()
                } else {
                    Image(systemName: "paperclip")
                }
            }
        }
        .accessibilityIdentifier("attachments.add")
        .photosPicker(isPresented: $model.isPresenting(.photos), selection: $model.photoItems,
                      maxSelectionCount: model.maxPhotoSelection, matching: .any(of: [.images, .videos]))
        .onChange(of: model.photoItems, model.photosChanged)
        .fileImporter(isPresented: $model.isPresenting(.files), allowedContentTypes: model.allowedContentTypes,
                      allowsMultipleSelection: true, onCompletion: model.filesPicked)
        .alert(Text("Add a Link", bundle: .module), isPresented: $model.isPresenting(.link)) {
            TextField(text: $model.linkText) { Text("Web address", bundle: .module) }
                .linkFieldStyle()
                .accessibilityIdentifier("attachments.link.field")
            Button(action: model.addLink) { Text("Add", bundle: .module) }
                .accessibilityIdentifier("attachments.link.add")
            Button(role: .cancel) {} label: { Text("Cancel", bundle: .module) }
        }
        .alert(Text("Couldn't Attach", bundle: .module), isPresented: $model.hasFailure) {
            Button(role: .cancel) {} label: { Text("OK", bundle: .module) }
        } message: {
            Text(model.failure ?? "")
        }
#if os(iOS)
        .fullScreenCover(isPresented: $model.isPresenting(.camera)) {
            CameraCapture { data in model.captured(data) }
                .ignoresSafeArea()
        }
#endif
    }
}

extension AttachmentPickerModel {
    /// A binding for one presentation's `isPresented`; dismissing clears it.
    func isPresenting(_ which: Presentation) -> Bool {
        presentation == which
    }

    var hasFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }
}

extension Bindable where Value == AttachmentPickerModel {
    /// `$model.isPresenting(.photos)`: the presentation as a Boolean binding.
    func isPresenting(_ which: AttachmentPickerModel.Presentation) -> Binding<Bool> {
        Binding(get: { wrappedValue.presentation == which },
                set: { shown in
                    if shown { wrappedValue.presentation = which } else if wrappedValue.presentation == which { wrappedValue.presentation = nil }
                })
    }
}
