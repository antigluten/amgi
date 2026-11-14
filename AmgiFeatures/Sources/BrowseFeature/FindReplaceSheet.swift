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
    @State private var confirming = false

    private var confirmMessage: LocalizedStringKey {
        model.noteIDs.isEmpty
            ? "This changes matching notes across the whole collection. You can undo it afterwards."
            : "This changes matching notes among ^[\(model.noteIDs.count) selected note](inflect: true). You can undo it afterwards."
    }

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
            .navigationTitle(String(localized: "Find & Replace", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done", bundle: .module)) { dismiss() }
                        .disabled(model.isWorking)
                }
                ToolbarItem(placement: .confirmationAction) { replaceControl }
            }
            .interactiveDismissDisabled(model.isWorking)
            .confirmationDialog(String(localized: "Replace in notes?", bundle: .module), isPresented: $confirming, titleVisibility: .visible) {
                confirmActions
            } message: {
                Text(confirmMessage, bundle: .module)
            }
            .task { await model.loadFieldNames() }
        }
    }

    @ViewBuilder
    private var replaceControl: some View {
        if model.isWorking {
            ProgressView()
        } else {
            Button(String(localized: "Replace", bundle: .module)) { confirming = true }
                .disabled(!model.canApply)
        }
    }

    @ViewBuilder
    private var confirmActions: some View {
        Button(String(localized: "Replace", bundle: .module), role: .destructive) { apply() }
    }

    @ViewBuilder
    private var scope: some View {
        if model.noteIDs.isEmpty {
            Text("Applies to every note in the collection.", bundle: .module)
        } else {
            Text("Applies to ^[\(model.noteIDs.count) selected note](inflect: true).", bundle: .module)
        }
    }

    private var inputSection: some View {
        @Bindable var model = model
        return Section {
            TextField(String(localized: "Find", bundle: .module), text: $model.find)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField(String(localized: "Replace With", bundle: .module), text: $model.replacement)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } footer: {
            scope
        }
    }

    private var optionsSection: some View {
        @Bindable var model = model
        return Section {
            Picker(String(localized: "In", bundle: .module), selection: $model.fieldName) {
                Text("All Fields", bundle: .module).tag("")
                ForEach(model.fieldNames, id: \.self) { Text($0).tag($0) }
            }
            Toggle(String(localized: "Treat input as regular expression", bundle: .module), isOn: $model.useRegex)
            Toggle(String(localized: "Match case", bundle: .module), isOn: $model.matchCase)
        }
    }

    @ViewBuilder
    private var outcomeSection: some View {
        if let outcome = model.outcome {
            Section {
                switch outcome {
                case .updated(let count):
                    Label {
                        Text("^[\(count) note](inflect: true) updated", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                    .foregroundStyle(palette.textPrimary)
                case .undone:
                    Label(String(localized: "Change undone", bundle: .module), systemImage: "arrow.uturn.backward")
                        .foregroundStyle(palette.textSecondary)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(palette.danger)
                }
                if model.canUndo {
                    Button(String(localized: "Undo", bundle: .module), systemImage: "arrow.uturn.backward") { undo() }
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
