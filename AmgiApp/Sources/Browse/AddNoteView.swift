import SwiftUI
import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.deckClient) var deckClient
    @Dependency(\.notetypesService) var notetypesService
    @Dependency(\.notesService) var notesService

    @State private var decks: [DeckInfo] = []
    @State private var notetypeNames: [(id: Int64, name: String)] = []
    @State private var selectedDeckId: Int64 = 1
    @State private var selectedNotetypeId: Int64 = 0
    @State private var fieldNames: [String] = []
    @State private var fieldValues: [String] = []
    @State private var tags: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck") {
                    Picker("Deck", selection: $selectedDeckId) {
                        ForEach(decks) { deck in
                            Text(deck.name).tag(deck.id)
                        }
                    }
                }

                Section("Note Type") {
                    Picker("Type", selection: $selectedNotetypeId) {
                        ForEach(notetypeNames, id: \.id) { entry in
                            Text(entry.name).tag(entry.id)
                        }
                    }
                    .onChange(of: selectedNotetypeId) {
                        loadFields()
                    }
                }

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

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await save() }
                    }
                    .disabled(isSaving || fieldValues.allSatisfy(\.isEmpty))
                }
            }
            .task {
                await loadData()
            }
        }
    }

    private func fieldBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < fieldValues.count ? fieldValues[index] : "" },
            set: { newValue in
                if index < fieldValues.count { fieldValues[index] = newValue }
            }
        )
    }

    private func loadData() async {
        decks = (try? deckClient.fetchAll()) ?? []
        if let first = decks.first { selectedDeckId = first.id }

        do {
            notetypeNames = try notetypesService.getNotetypeNames()
            if let first = notetypeNames.first {
                selectedNotetypeId = first.id
                loadFields()
            }
        } catch {
            print("[AddNote] Error loading notetypes: \(error)")
        }
    }

    private func loadFields() {
        guard selectedNotetypeId != 0 else { return }
        do {
            let notetype = try notetypesService.getNotetype(selectedNotetypeId)
            fieldNames = notetype.fieldNames
            fieldValues = Array(repeating: "", count: fieldNames.count)
        } catch {
            print("[AddNote] Error loading fields: \(error)")
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            var template = try notesService.newNote(selectedNotetypeId)
            template.fields = fieldValues
            template.tags = tags.split(separator: " ").map(String.init)
            try notesService.addNote(template, selectedDeckId)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to add note: \(error.localizedDescription)"
        }
        isSaving = false
    }
}
