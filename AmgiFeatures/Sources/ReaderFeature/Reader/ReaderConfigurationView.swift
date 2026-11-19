//
//  ReaderConfigurationView.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import Theme
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

    @State private var model = ReaderConfigurationModel()
    @Environment(\.palette) private var palette

    @Shared(.appStorage(ReaderPreferenceKey.deckName)) private var deckName: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.bookIDField)) private var bookIDField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.bookTitleField)) private var bookTitleField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.bookCoverField)) private var bookCoverField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.chapterTitleField)) private var chapterTitleField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.chapterOrderField)) private var chapterOrderField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.contentField)) private var contentField: String = ""
    @Shared(.appStorage(ReaderPreferenceKey.languageField)) private var languageField: String = ""

    var body: some View {
        Form {
            Section(String(localized: "Deck", bundle: .module)) {
                if model.decks.isEmpty {
                    Text("Loading decks…", bundle: .module).foregroundStyle(palette.textSecondary)
                } else {
                    Picker(String(localized: "Deck", bundle: .module), selection: Binding($deckName)) {
                        Text("Select a deck", bundle: .module).tag("")
                        ForEach(model.decks, id: \.id) { deck in
                            Text(deck.name).tag(deck.name)
                        }
                    }
                }
            }

            Section {
                LabeledContent(String(localized: "Book ID", bundle: .module)) {
                    TextField(String(localized: "Book ID field", bundle: .module), text: Binding($bookIDField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "Book title", bundle: .module)) {
                    TextField(String(localized: "Book title field", bundle: .module), text: Binding($bookTitleField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "Book cover", bundle: .module)) {
                    TextField(String(localized: "Optional", bundle: .module), text: Binding($bookCoverField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "Chapter title", bundle: .module)) {
                    TextField(String(localized: "Chapter title field", bundle: .module), text: Binding($chapterTitleField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "Chapter order", bundle: .module)) {
                    TextField(String(localized: "Chapter order field", bundle: .module), text: Binding($chapterOrderField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "Content", bundle: .module)) {
                    TextField(String(localized: "Content field", bundle: .module), text: Binding($contentField))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "Language", bundle: .module)) {
                    TextField(String(localized: "Optional", bundle: .module), text: Binding($languageField))
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Field mapping", bundle: .module)
            } footer: {
                Text("Field names from the notetype that holds your book chapters. Each note becomes a chapter; chapters with the same Book ID collapse into one book.", bundle: .module)
            }

            if let loadError = model.loadError {
                Section { Text(loadError).foregroundStyle(palette.danger) }
            }
        }
        .navigationTitle(String(localized: "Reader Setup", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Done", bundle: .module)) { onDismiss() }
            }
        }
        .task { await model.loadDecks() }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    // deckClient.previewValue feeds the deck picker; the field-mapping rows
    // read their @Shared appStorage defaults.
    let _ = prepareDependencies { $0.deckClient = .previewValue }
    return NavigationStack {
        ReaderConfigurationView(onDismiss: {})
    }
}
#endif
