import SwiftUI
import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies

struct NoteEditorView: View {
    let note: NoteRecord
    let onSave: () -> Void

    @Dependency(\.noteClient) var noteClient
    @Dependency(\.notetypesService) var notetypesService

    @State private var fieldValues: [String] = []
    @State private var fieldNames: [String] = []
    @State private var tags: String = ""
    @State private var isSaving = false
    @State private var showSavedConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Fields") {
                ForEach(Array(fieldNames.enumerated()), id: \.offset) { index, name in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(name, text: fieldBinding(for: index), axis: .vertical)
                            .lineLimit(1...5)
                    }
                }
            }

            Section("Tags") {
                TextField("Tags (space-separated)", text: $tags)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
        .overlay {
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
        .task { loadNote() }
    }

    private func fieldBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < fieldValues.count ? fieldValues[index] : "" },
            set: { newValue in
                if index < fieldValues.count { fieldValues[index] = newValue }
            }
        )
    }

    private func loadNote() {
        do {
            let notetype = try notetypesService.getNotetype(note.mid)
            fieldNames = notetype.fieldNames
        } catch {
            print("[NoteEditorView] Error loading notetype: \(error)")
        }

        fieldValues = note.flds
            .split(separator: "\u{1f}", omittingEmptySubsequences: false)
            .map(String.init)
        while fieldValues.count < fieldNames.count { fieldValues.append("") }
        tags = note.tags.trimmingCharacters(in: .whitespaces)
    }

    private func save() async {
        isSaving = true
        let newFlds = fieldValues.joined(separator: "\u{1f}")
        let newSfld = fieldValues.first ?? ""
        let newCsum = Int64(newSfld.hashValue & 0xFFFFFFFF)

        var updatedNote = note
        updatedNote.flds = newFlds
        updatedNote.sfld = newSfld
        updatedNote.csum = newCsum
        updatedNote.tags = " \(tags) "

        do {
            try noteClient.save(updatedNote)
            withAnimation { showSavedConfirmation = true }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showSavedConfirmation = false }
            onSave()
        } catch {}
        isSaving = false
    }
}
