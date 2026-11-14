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
                    TextField(String(localized: "Deck name", bundle: .module), text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(String(localized: "Rename Deck", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", bundle: .module)) {
                        Task { await rename() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert(
                String(localized: "Couldn't rename deck", bundle: .module),
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button(String(localized: "OK", bundle: .module)) {}
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
            errorMessage = String(localized: "Failed to rename deck: \(error.localizedDescription)", bundle: .module)
        }
        isSaving = false
    }
}
