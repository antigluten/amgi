//
//  BatchTagSheet.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 03.05.2026.
//

import SwiftUI
import AnkiClients
import AnkiKit
import Dependencies
import Theme

struct BatchTagSheet: View {
    let noteIDs: Set<NoteID>
    let onApplied: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var model = BatchTagModel()
    @State private var checkedTags: Set<String> = []
    @State private var newTagName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "New tag", bundle: .module)) {
                    HStack {
                        TextField(String(localized: "Add new tag", bundle: .module), text: $newTagName)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button(String(localized: "Add", bundle: .module)) {
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

                Section(String(localized: "Existing tags", bundle: .module)) {
                    if model.allTags.isEmpty {
                        Text("No tags yet", bundle: .module).foregroundStyle(palette.textSecondary)
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
                                        .foregroundStyle(checkedTags.contains(tag) ? palette.accent : palette.textSecondary)
                                    Text(tag).foregroundStyle(palette.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Add tags to \(noteIDs.count) notes", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Apply", bundle: .module)) { apply() }
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
