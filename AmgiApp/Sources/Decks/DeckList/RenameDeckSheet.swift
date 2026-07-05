import SwiftUI
import AnkiKit
import AnkiClients
import Dependencies

// MARK: - RenameDeckSheet

struct RenameDeckSheet: View {
    let deckId: DeckID
    let onDone: () -> Void

    @Dependency(\.deckClient) var deckClient
    @State private var name: String
    @State private var isSaving = false
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
        }
    }

}

private extension RenameDeckSheet {
    func rename() async {
        isSaving = true
        do {
            _ = try await deckClient.rename(deckId, name.trimmingCharacters(in: .whitespaces))
            onDone()
        } catch {
            print("[RenameDeckSheet] Rename failed: \(error)")
        }
        isSaving = false
    }
}
