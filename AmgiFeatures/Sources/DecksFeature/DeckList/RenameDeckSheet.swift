//
//  RenameDeckSheet.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import AppShared
import Theme
import AnkiKit
import AnkiClients
import Dependencies

// MARK: - RenameDeckSheet

struct RenameDeckSheet: View {
    let deckId: DeckID
    let onDone: () -> Void

    @Dependency(\.deckClient) var deckClient
    @Dependency(\.collectionStore) var store
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(deckId: DeckID, currentName: String, onDone: @escaping () -> Void) {
        self.deckId = deckId
        self.onDone = onDone
        _name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck name", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Rename Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await rename() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert(
                "Couldn't rename deck",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button("OK") {}
            } message: { message in
                Text(message)
            }
        }
    }

}

private extension RenameDeckSheet {
    func rename() async {
        isSaving = true
        do {
            let changes = try await deckClient.rename(deckId, name.trimmingCharacters(in: .whitespaces))
            store.apply(changes)
            onDone()
        } catch {
            errorMessage = "Failed to rename deck: \(error.localizedDescription)"
        }
        isSaving = false
    }
}
