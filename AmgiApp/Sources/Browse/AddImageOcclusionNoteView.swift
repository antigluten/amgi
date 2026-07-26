import SwiftUI
import PhotosUI
import AmgiTheme
import AnkiKit

// MARK: - AddImageOcclusionNoteView

/// Add Image Occlusion container: owns the modal chrome, the photo picker
/// selection, and the occlusion-editor cover, and drives an
/// `AddImageOcclusionModel` for deck loading and the note write. The form is
/// `AddImageOcclusionContent`, bound to the model.
struct AddImageOcclusionNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AddImageOcclusionModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showOcclusionEditor = false

    let onSave: () -> Void

    init(onSave: @escaping () -> Void, preselectedDeckId: DeckID? = nil) {
        self.onSave = onSave
        _model = State(initialValue: AddImageOcclusionModel(preselectedDeckId: preselectedDeckId))
    }

    var body: some View {
        NavigationStack {
            AddImageOcclusionContent(
                model: model,
                selectedItem: $selectedItem,
                onEditMasks: { showOcclusionEditor = true }
            )
            .toolbar(.hidden, for: .tabBar)
            .navigationTitle("Image Occlusion")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadDecks() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            if await model.save() {
                                onSave()
                                dismiss()
                            }
                        }
                    }
                    .amgiToolbarTextButton()
                    .disabled(!model.canSave || model.isSaving)
                    .overlay {
                        if model.isSaving { ProgressView().scaleEffect(0.7) }
                    }
                }
            }
            .fullScreenCover(isPresented: $showOcclusionEditor) {
                if let selectedImage = model.selectedImage {
                    NavigationStack {
                        ImageOcclusionWorkspaceView(
                            title: "Edit",
                            image: selectedImage,
                            initialMasks: model.masks
                        ) { updatedMasks in
                            model.masks = updatedMasks
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AddImageOcclusionContent

/// The Add Image Occlusion form: deck picker, image picker, mask summary,
/// content + tags fields. Bound to an `AddImageOcclusionModel`; owns no I/O
/// of its own, so it renders in a `#Preview` from a seeded model.
struct AddImageOcclusionContent: View {
    @Bindable var model: AddImageOcclusionModel
    @Binding var selectedItem: PhotosPickerItem?
    let onEditMasks: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Form {
            Section("Deck") {
                Picker("Deck", selection: $model.selectedDeckId) {
                    ForEach(model.decks) { deck in
                        Text(deck.name).tag(deck.id)
                    }
                }
            }

            Section {
                Text("Add Image Occlusion")
                    .foregroundStyle(palette.textPrimary)
            } header: {
                Text("Note Type")
            } footer: {
                Text("Pick an image, draw occlusions over the regions you want to test, then save.")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            Section {
                // Resolved in the (main-actor) ViewBuilder and captured by
                // value: the PhotosPicker label closure is Sendable, so it
                // can't read main-actor model state directly.
                let pickImageSymbol = model.selectedImage == nil
                    ? "photo.on.rectangle.angled"
                    : "photo.badge.plus"
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Pick image", systemImage: pickImageSymbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: selectedItem) {
                    Task { await model.loadImage(from: selectedItem) }
                }
            } header: {
                Text("Image")
            }

            if let uiImage = model.selectedImage {
                Section {
                    ImageOcclusionMaskSummaryCard(image: uiImage, masks: model.masks) {
                        onEditMasks()
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Masks")
                } footer: {
                    Text("Tap and drag to draw a mask. Drag handles to resize.")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            Section("Content") {
                TextField("Header", text: $model.header)
                TextField("Extra info shown on the back", text: $model.backExtra)
            }

            Section {
                TextField("Tags", text: $model.tagsText)
            } header: {
                Text("Tags")
            } footer: {
                Text("Space-separated")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }

            if let err = model.errorMessage {
                Section {
                    Text(err)
                        .amgiStatusText(.danger, font: .caption)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // The "no image yet" state — seeded decks + content, no UIImage so the
    // mask section stays hidden. Renders without a backend.
    let model = AddImageOcclusionModel()
    model.decks = [.sample, .filtered]
    model.selectedDeckId = DeckInfo.sample.id
    model.header = "Diagram of the heart"
    model.tagsText = "anatomy biology"
    return NavigationStack {
        AddImageOcclusionContent(
            model: model,
            selectedItem: .constant(nil),
            onEditMasks: {}
        )
        .navigationTitle("Image Occlusion")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
