import SwiftUI
import AnkiClients
import AnkiKit
import Dependencies

struct BatchTagSheet: View {
    let noteIDs: Set<NoteID>
    let onApplied: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var model = BatchTagModel()
    @State private var checkedTags: Set<String> = []
    @State private var newTagName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("New tag") {
                    HStack {
                        TextField("Add new tag", text: $newTagName)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button("Add") {
                            let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            checkedTags.insert(trimmed)
                            if !model.allTags.contains(trimmed) {
                                model.allTags.append(trimmed)
                                model.allTags.sort()
                            }
                            newTagName = ""
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Existing tags") {
                    if model.allTags.isEmpty {
                        Text("No tags yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(model.allTags, id: \.self) { tag in
                            Button {
                                if checkedTags.contains(tag) {
                                    checkedTags.remove(tag)
                                } else {
                                    checkedTags.insert(tag)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: checkedTags.contains(tag) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(checkedTags.contains(tag) ? Color.accentColor : Color.secondary)
                                    Text(tag).foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add tags to \(noteIDs.count) note\(noteIDs.count == 1 ? "" : "s")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { apply() }
                        .disabled(checkedTags.isEmpty || model.isApplying)
                }
            }
            .task { await model.loadTags() }
        }
    }

}

private extension BatchTagSheet {
    func apply() {
        Task {
            await model.apply(noteIDs: noteIDs, tags: checkedTags)
            onApplied()
            dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let _ = prepareDependencies {
        $0.tagClient.getAllTags = { ["grammar", "vocab", "n5", "verb", "adjective"] }
    }
    return BatchTagSheet(noteIDs: [NoteID(1), NoteID(2)], onApplied: {})
}
#endif
