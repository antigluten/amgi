//
//  CreateDeckSheet.swift
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

// MARK: - CreateDeckSheet

/// Trivial sheet — keeps `@Dependency` inline. Previewed via
/// `withDependencies { $0.deckClient = .previewValue }`.
struct CreateDeckSheet: View {
    let onDone: () -> Void

    @Dependency(\.deckClient) var deckClient
    @Dependency(\.collectionStore) var store
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deck name, use :: for subdecks", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await create() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .alert(
                "Couldn't create deck",
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

private extension CreateDeckSheet {
    func create() async {
        isSaving = true
        do {
            let creation = try await deckClient.create(name.trimmingCharacters(in: .whitespaces))
            store.apply(creation.changes)
            onDone()
        } catch {
            errorMessage = "Failed to create deck: \(error.localizedDescription)"
        }
        isSaving = false
    }
}
