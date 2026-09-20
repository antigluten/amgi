//
//  NoteEditorView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 27.03.2026.
//

package import SwiftUI
package import AnkiKit
import Theme

/// Edit Note container: owns the toolbar and the transient "Saved" toast, and
/// drives a `NoteEditorModel` for the notetype lookup + note write. The form
/// is `NoteEditorContent`, bound to the model.
package struct NoteEditorView: View {
    @State private var model: NoteEditorModel
    let onSave: () -> Void

    @State private var showSavedConfirmation = false
    @State private var savedToastTask: Task<Void, Never>?

    package init(note: NoteRecord, onSave: @escaping () -> Void) {
        _model = State(initialValue: NoteEditorModel(note: note))
        self.onSave = onSave
    }

    package var body: some View {
        NoteEditorContent(model: model)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savedToastTask = Task {
                            if await model.save() {
                                withAnimation(AmgiMotion.momentum) { showSavedConfirmation = true }
                                try? await Task.sleep(for: .seconds(1.5))
                                withAnimation(AmgiMotion.standard) { showSavedConfirmation = false }
                                onSave()
                            }
                        }
                    }
                    // Stay disabled across the "Saved" toast too — the model's
                    // isSaving flag clears the instant the write returns, but a
                    // second tap during the 1.5s toast would re-save and re-fire
                    // onSave (the pre-extraction save() held isSaving across the
                    // toast).
                    .disabled(model.isSaving || showSavedConfirmation)
                }
            }
            .overlay { savedToast }
            .task { await model.loadNote() }
    }

    @ViewBuilder
    private var savedToast: some View {
        if showSavedConfirmation {
            VStack {
                Spacer()
                Button { savedToastTask?.cancel() } label: {
                    Text("Saved")
                        .amgiFont(.bodyEmphasis)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .amgiMaterial(.light, in: Capsule())
                }
                .buttonStyle(.pressScale)
                .accessibilityHint("Dismisses this message")
                .padding(.bottom, 32)
            }
            .transition(AmgiMotion.slide(from: .bottom))
        }
    }
}

// MARK: - NoteEditorContent

/// The Edit Note form: the note-type's fields and a tags field. Bound to a
/// `NoteEditorModel`; owns no I/O, so it renders in a `#Preview` from a
/// seeded model.
struct NoteEditorContent: View {
    @Environment(\.palette) private var palette
    @Bindable var model: NoteEditorModel

    var body: some View {
        Form {
            Section("Fields") {
                ForEach(Array(model.fieldNames.enumerated()), id: \.element) { index, name in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .amgiFont(.caption)
                            .foregroundStyle(palette.textSecondary)
                        RichNoteFieldEditor(htmlText: $model[fieldAt: index])
                    }
                }
            }

            Section("Tags") {
                TextField("Tags (space-separated)", text: $model.tags)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let model = NoteEditorModel(note: NoteRecord(
        id: NoteID(1), guid: "g1", mid: NotetypeID(1), mod: 0, flds: "", sfld: "", csum: 0
    ))
    model.fieldNames = ["Front", "Back"]
    model.fieldValues = ["안녕하세요", "Hello"]
    model.tags = "vocab korean"
    return NavigationStack {
        NoteEditorContent(model: model)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
