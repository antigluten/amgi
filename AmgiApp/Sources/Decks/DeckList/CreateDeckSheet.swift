import SwiftUI
import AnkiKit
import AnkiClients
import Dependencies

// MARK: - CreateDeckSheet

/// Trivial sheet — keeps `@Dependency` inline. Previewed via
/// `withDependencies { $0.deckClient = .previewValue }`.
struct CreateDeckSheet: View {
    let onDone: () -> Void

    @Dependency(\.deckClient) var deckClient
    @State private var name = ""
    @State private var isSaving = false
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
        }
    }

}

private extension CreateDeckSheet {
    func create() async {
        isSaving = true
        do {
            _ = try deckClient.create(name.trimmingCharacters(in: .whitespaces))
            onDone()
        } catch {
            print("[CreateDeckSheet] Create failed: \(error)")
        }
        isSaving = false
    }
}
