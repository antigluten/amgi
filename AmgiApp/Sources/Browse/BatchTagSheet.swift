import SwiftUI
import AnkiClients
import Dependencies

struct BatchTagSheet: View {
    let noteIDs: Set<Int64>
    let onApplied: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Dependency(\.tagClient) private var tagClient

    @State private var allTags: [String] = []
    @State private var checkedTags: Set<String> = []
    @State private var newTagName: String = ""
    @State private var isApplying = false

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
                            if !allTags.contains(trimmed) {
                                allTags.append(trimmed)
                                allTags.sort()
                            }
                            newTagName = ""
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Existing tags") {
                    if allTags.isEmpty {
                        Text("No tags yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(allTags, id: \.self) { tag in
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
                        .disabled(checkedTags.isEmpty || isApplying)
                }
            }
            .task {
                if let tags = try? tagClient.getAllTags() {
                    allTags = tags.sorted()
                }
            }
        }
    }

    private func apply() {
        isApplying = true
        let ids = Array(noteIDs)
        let tags = checkedTags
        Task {
            for tag in tags {
                try? tagClient.addTagToNotes(tag, ids)
            }
            await MainActor.run {
                isApplying = false
                onApplied()
                dismiss()
            }
        }
    }
}
