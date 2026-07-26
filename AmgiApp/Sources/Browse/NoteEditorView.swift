import SwiftUI
import AnkiKit

/// Edit Note container: owns the toolbar and the transient "Saved" toast, and
/// drives a `NoteEditorModel` for the notetype lookup + note write. The form
/// is `NoteEditorContent`, bound to the model.
struct NoteEditorView: View {
    @State private var model: NoteEditorModel
    let onSave: () -> Void

    @State private var showSavedConfirmation = false

    init(note: NoteRecord, onSave: @escaping () -> Void) {
        _model = State(initialValue: NoteEditorModel(note: note))
        self.onSave = onSave
    }

    var body: some View {
        NoteEditorContent(model: model)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await model.save() {
                                withAnimation { showSavedConfirmation = true }
                                try? await Task.sleep(for: .seconds(1.5))
                                withAnimation { showSavedConfirmation = false }
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
            .task { model.loadNote() }
    }

    @ViewBuilder
    private var savedToast: some View {
        if showSavedConfirmation {
            VStack {
                Spacer()
                Text("Saved")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 32)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - NoteEditorContent

/// The Edit Note form: the note-type's fields and a tags field. Bound to a
/// `NoteEditorModel`; owns no I/O, so it renders in a `#Preview` from a
/// seeded model.
struct NoteEditorContent: View {
    @Bindable var model: NoteEditorModel

    var body: some View {
        Form {
            Section("Fields") {
                ForEach(Array(model.fieldNames.enumerated()), id: \.offset) { index, name in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        RichNoteFieldEditor(htmlText: model.fieldBinding(for: index))
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
