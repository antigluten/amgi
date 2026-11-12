import AppCore
import AnkiBackend
import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Foundation

@MainActor
enum WordSpotlightSource {
    static func load(_ preferences: WordSpotlightPreferences, validate: () throws -> Void) async throws -> [SpotlightWord] {
        @Dependency(\.notesService) var notesService
        @Dependency(\.notetypesClient) var notetypesClient
        @Dependency(\.deckClient) var deckClient
        let decks = try await deckClient.fetchAll()
        try validate()
        guard let deck = decks.first(where: { $0.id.rawValue == preferences.deckID }) else {
            throw WordSpotlightError.invalidSource
        }
        let notetype = try await notetypesClient.get(NotetypeID(preferences.notetypeID))
        try validate()
        let fields = notetype.fields.map(\.name)
        guard fields.contains(preferences.termField), fields.contains(preferences.meaningField),
              preferences.readingField.isEmpty || fields.contains(preferences.readingField) else {
            throw WordSpotlightError.invalidSource
        }
        let query = "\(DeckSearch.term(deck.name)) mid:\(preferences.notetypeID) -is:suspended -is:buried"
        // shortcut: only the 500 oldest notes rotate; add paged rotation if larger pools are needed.
        let notes = try await backendOffload {
            try notesService.searchNoteIds(query)
                .sorted { $0.rawValue < $1.rawValue }
                .prefix(500)
                .compactMap { try? notesService.getNote($0) }
        }
        try validate()
        let words = await words(from: notes, fields: fields, preferences: preferences)
        try validate()
        return words
    }

    @concurrent
    nonisolated private static func words(
        from notes: [NoteRecord], fields: [String], preferences: WordSpotlightPreferences
    ) async -> [SpotlightWord] {
        notes.compactMap {
            word(from: $0, fields: fields, preferences: preferences)
        }
    }

    nonisolated static func word(
        from note: NoteRecord, fields: [String], preferences: WordSpotlightPreferences
    ) -> SpotlightWord? {
        guard !note.isImageOcclusionNote else { return nil }
        let values = note.flds.components(separatedBy: "\u{1f}")
        func text(_ name: String) -> String {
            guard let index = fields.firstIndex(of: name), values.indices.contains(index) else { return "" }
            // Preserve separation between HTML blocks before using the shared Anki text parser.
            let html = values[index].replacingOccurrences(
                of: #"(?i)<br\s*/?>|</(?:div|p|li)>"#, with: "\n", options: .regularExpression
            )
            return CardText.plainText(html)
        }
        let term = text(preferences.termField)
        let meaning = text(preferences.meaningField)
        guard !term.isEmpty, !meaning.isEmpty,
              !term.contains("{{c"), !meaning.contains("{{c") else { return nil }
        return SpotlightWord(noteID: note.id.rawValue, term: term, reading: text(preferences.readingField), meaning: meaning)
    }
}
