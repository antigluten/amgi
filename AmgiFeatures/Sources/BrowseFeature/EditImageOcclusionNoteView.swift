//
//  EditImageOcclusionNoteView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 29.04.2026.
//

#if canImport(UIKit)
import SwiftUI
import AnkiKit
import Theme
import UI

// MARK: - EditImageOcclusionNoteView

/// Edit Image Occlusion container: owns the (optional) navigation wrapper,
/// the toolbar, and the occlusion-editor cover, and drives an
/// `EditImageOcclusionModel` for the note fetch + update. The form is
/// `EditImageOcclusionContent`, bound to the model.
struct EditImageOcclusionNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: EditImageOcclusionModel
    @State private var showOcclusionEditor = false

    let onSave: () -> Void
    let embedInNavigationStack: Bool

    init(noteId: NoteID, onSave: @escaping () -> Void, embedInNavigationStack: Bool = true) {
        _model = State(initialValue: EditImageOcclusionModel(noteId: noteId))
        self.onSave = onSave
        self.embedInNavigationStack = embedInNavigationStack
    }

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    editorBody
                }
            } else {
                editorBody
            }
        }
    }

    private var editorBody: some View {
        EditImageOcclusionContent(
            model: model,
            onEditMasks: { showOcclusionEditor = true }
        )
        .toolbarVisibility(.hidden, for: .tabBar)
        .navigationTitle(String(localized: "Edit Image Occlusion", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if embedInNavigationStack {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
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
                .disabled(!model.canSave)
                .overlay { if model.isSaving { ProgressView().scaleEffect(0.7) } }
            }
        }
        .fullScreenCover(isPresented: $showOcclusionEditor) {
            if let uiImage = model.uiImage {
                NavigationStack {
                    ImageOcclusionWorkspaceView(
                        title: String(localized: "Edit", bundle: .module),
                        image: uiImage,
                        initialMasks: model.masks
                    ) { updatedMasks in
                        model.masks = updatedMasks
                    }
                }
            }
        }
        .task { await model.loadNote() }
    }
}

// MARK: - EditImageOcclusionContent

/// The Edit Image Occlusion form: loading/error states, the mask summary,
/// and the content + tags fields. Bound to an `EditImageOcclusionModel`;
/// owns no I/O, so it renders in a `#Preview` from a seeded model.
struct EditImageOcclusionContent: View {
    @Bindable var model: EditImageOcclusionModel
    let onEditMasks: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        if model.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = model.loadError {
            AmgiStatusMessageView(
                title: String(localized: "Error", bundle: .module),
                message: err,
                systemImage: "exclamationmark.triangle",
                tone: .warning
            )
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            if let img = model.uiImage {
                Section {
                    ImageOcclusionMaskSummaryCard(image: img, masks: model.masks) {
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

            if let err = model.saveError {
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
    // The loaded-without-image state — seeded content/tags, no UIImage so the
    // mask section stays hidden. Renders without a backend.
    let model = EditImageOcclusionModel(noteId: NoteID(1))
    model.isLoading = false
    model.header = "Diagram of the heart"
    model.backExtra = "The left ventricle pumps oxygenated blood to the body."
    model.tagsText = "anatomy biology"
    return NavigationStack {
        EditImageOcclusionContent(model: model, onEditMasks: {})
            .navigationTitle("Edit Image Occlusion")
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
#endif
