//
//  FindReplaceSheet.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 22.10.2026.
//

import SwiftUI
import AnkiClients
import AnkiKit
import Dependencies
import Theme

struct FindReplaceSheet: View {
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var model: FindReplaceModel

    // Empty `noteIDs` means the whole collection.
    init(noteIDs: [NoteID], onChanged: @escaping () -> Void) {
        _model = State(initialValue: FindReplaceModel(noteIDs: noteIDs))
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                optionsSection
                outcomeSection
            }
            .navigationTitle("Find & Replace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Replace") { apply() }
                        .disabled(!model.canApply)
                }
            }
            .task { await model.loadFieldNames() }
        }
    }

    @ViewBuilder
    private var scope: some View {
        if model.noteIDs.isEmpty {
            Text("Applies to every note in the collection.")
        } else {
            Text("Applies to ^[\(model.noteIDs.count) selected note](inflect: true).")
        }
    }

    private var inputSection: some View {
        @Bindable var model = model
        return Section {
            TextField("Find", text: $model.find)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField("Replace With", text: $model.replacement)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } footer: {
            scope
        }
    }

    private var optionsSection: some View {
        @Bindable var model = model
        return Section {
            Picker("In", selection: $model.fieldName) {
                Text("All Fields").tag("")
                ForEach(model.fieldNames, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Treat input as regular expression", isOn: $model.useRegex)
            Toggle("Match case", isOn: $model.matchCase)
        }
    }

    @ViewBuilder
    private var outcomeSection: some View {
        if let outcome = model.outcome {
            Section {
                switch outcome {
                case .updated(let count):
                    Label {
                        Text("^[\(count) note](inflect: true) updated")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                    .foregroundStyle(palette.textPrimary)
                case .undone:
                    Label("Change undone", systemImage: "arrow.uturn.backward")
                        .foregroundStyle(palette.textSecondary)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(palette.danger)
                }
                if model.canUndo {
                    Button("Undo", systemImage: "arrow.uturn.backward") { undo() }
                        .disabled(model.isWorking)
                }
            }
        }
    }

    private func apply() {
        Task {
            await model.apply()
            onChanged()
        }
    }

    private func undo() {
        Task {
            await model.undo()
            onChanged()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let _ = prepareDependencies {
        $0.noteClient.fieldNamesForNotes = { _ in ["Front", "Back"] }
        $0.noteClient.findAndReplace = { _, _, _, _, _, _ in 3 }
        $0.cardClient.undoLast = {}
    }
    return FindReplaceSheet(noteIDs: [NoteID(1), NoteID(2)], onChanged: {})
}
#endif
