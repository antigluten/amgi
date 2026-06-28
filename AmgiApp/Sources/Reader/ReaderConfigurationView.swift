import AnkiClients
import AnkiKit
import Dependencies
import Sharing
import SwiftUI

/// Picks the deck that holds books and maps notetype field names onto the
/// book/chapter shape the reader expects. Persists each value via
/// `@Shared(.appStorage)` so the library view sees changes immediately.
struct ReaderConfigurationView: View {
    let onDismiss: () -> Void

    @Dependency(\.deckClient) var deckClient

    @Shared(.appStorage(ReaderPreferenceKey.deckName)) private var deckName: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.bookIDField)) private var bookIDField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.bookTitleField)) private var bookTitleField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.bookCoverField)) private var bookCoverField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.chapterTitleField)) private var chapterTitleField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.chapterOrderField)) private var chapterOrderField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.contentField)) private var contentField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.languageField)) private var languageField: String = ""

    @State private var decks: [DeckInfo] = []
    @State private var loadError: String?

    var body: some View {
        Form {
            Section("Deck") {
                if decks.isEmpty {
                    Text("Loading decks…").foregroundStyle(.secondary)
                } else {
                    Picker("Deck", selection: Binding($deckName)) {
                        Text("Select a deck").tag("")
                        ForEach(decks, id: \.id) { deck in
                            Text(deck.name).tag(deck.name)
                        }
                    }
                }
            }

            Section {
                LabeledContent("Book ID") {
                    TextField("Book ID field", text: Binding($bookIDField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Book title") {
                    TextField("Book title field", text: Binding($bookTitleField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Book cover") {
                    TextField("Optional", text: Binding($bookCoverField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Chapter title") {
                    TextField("Chapter title field", text: Binding($chapterTitleField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Chapter order") {
                    TextField("Chapter order field", text: Binding($chapterOrderField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Content") {
                    TextField("Content field", text: Binding($contentField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Language") {
                    TextField("Optional", text: Binding($languageField))
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Field mapping")
            } footer: {
                Text("Field names from the notetype that holds your book chapters. Each note becomes a chapter; chapters with the same Book ID collapse into one book.")
            }

            if let loadError {
                Section { Text(loadError).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Reader Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDismiss() }
            }
        }
        .task { await loadDecks() }
    }

    private func loadDecks() async {
        do {
            decks = try deckClient.fetchAll().sorted { $0.name < $1.name }
        } catch {
            loadError = "Failed to load decks: \(error.localizedDescription)"
        }
    }
}
