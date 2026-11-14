//
//  AddImageOcclusionNoteView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 29.04.2026.
//

#if canImport(UIKit)
import SwiftUI
import PhotosUI
import Theme
import UI
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
    @State private var showDiscardConfirm = false

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
            .toolbarVisibility(.hidden, for: .tabBar)
            .navigationTitle(String(localized: "Image Occlusion", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadDecks() }
            .interactiveDismissDisabled(model.hasUnsavedChanges)
            .confirmationDialog(
                String(localized: "Discard this note?", bundle: .module),
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Discard", bundle: .module), role: .destructive) { dismiss() }
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            } message: {
                Text("The note hasn't been saved yet. Discarding loses the image and its masks.", bundle: .module)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) {
                        if model.hasUnsavedChanges {
                            showDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                    .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", bundle: .module)) {
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
                            title: String(localized: "Edit", bundle: .module),
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
            Section(String(localized: "Deck", bundle: .module)) {
                Picker(String(localized: "Deck", bundle: .module), selection: $model.selectedDeckId) {
                    ForEach(model.decks) { deck in
                        Text(deck.name).tag(deck.id)
                    }
                }
            }

            Section {
                Text("Add Image Occlusion", bundle: .module)
                    .foregroundStyle(palette.textPrimary)
            } header: {
                Text("Note Type", bundle: .module)
            } footer: {
                Text("Pick an image, draw occlusions over the regions you want to test, then save.", bundle: .module)
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
                    Label(String(localized: "Pick image", bundle: .module), systemImage: pickImageSymbol)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: selectedItem) {
                    Task { await model.loadImage(from: selectedItem) }
                }
            } header: {
                Text("Image", bundle: .module)
            }

            if let uiImage = model.selectedImage {
                Section {
                    ImageOcclusionMaskSummaryCard(image: uiImage, masks: model.masks) {
                        onEditMasks()
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Masks", bundle: .module)
                } footer: {
                    Text("Tap and drag to draw a mask. Drag handles to resize.", bundle: .module)
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            Section(String(localized: "Content", bundle: .module)) {
                TextField(String(localized: "Header", bundle: .module), text: $model.header)
                TextField(String(localized: "Extra info shown on the back", bundle: .module), text: $model.backExtra)
            }

            Section {
                TextField(String(localized: "Tags", bundle: .module), text: $model.tagsText)
            } header: {
                Text("Tags", bundle: .module)
            } footer: {
                Text("Space-separated", bundle: .module)
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
#endif
