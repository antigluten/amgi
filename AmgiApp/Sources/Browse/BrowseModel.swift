import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Foundation

/// Data state + load/search/mutation logic for the Browse screen. Mirrors
/// `DeckListModel`: the View owns navigation, sheets, selection, and the
/// toolbar, while the model owns I/O, paging, and query assembly so that
/// logic is testable in isolation and the View stays a thin presentation
/// wiring layer.
@Observable
@MainActor
final class BrowseModel {
    var searchText = ""
    var allNotes: [NoteRecord] = []
    var notes: [NoteRecord] = []
    var allDecks: [DeckInfo] = []
    /// The top-level parent deck selected (stays set even when drilling into subdecks).
    var parentDeck: DeckInfo?
    /// The actual deck filter applied (could be parent or a subdeck).
    var activeDeck: DeckInfo?
    var isLoading = false
    var hasMorePages = true
    var allTags: [String] = []
    var activeTag: String?
    var sortOrder: BrowseSortOrder = .dateDesc
    var notetypeNames: [NotetypeID: String] = [:]

    private let pageSize = 50

    @ObservationIgnored @Dependency(\.noteClient) private var noteClient
    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.cardClient) private var cardClient
    @ObservationIgnored @Dependency(\.tagClient) private var tagClient
    @ObservationIgnored @Dependency(\.notetypesService) private var notetypesService

    // MARK: - Derived

    var sortedNotes: [NoteRecord] {
        switch sortOrder {
        case .dateDesc:
            return notes.sorted { $0.mod > $1.mod }
        case .titleAsc:
            return notes.sorted { $0.sfld.localizedCaseInsensitiveCompare($1.sfld) == .orderedAscending }
        case .templateAsc:
            return notes.sorted { (notetypeNames[$0.mid] ?? "") < (notetypeNames[$1.mid] ?? "") }
        }
    }

    var topLevelDecks: [DeckInfo] {
        allDecks.filter { !$0.name.contains("::") }
    }

    /// Direct children of the parent deck (shown as the second filter row).
    var childDecks: [DeckInfo] {
        guard let parent = parentDeck else { return [] }
        let prefix = parent.name + "::"
        return allDecks.filter { deck in
            guard deck.name.hasPrefix(prefix) else { return false }
            let remainder = deck.name.dropFirst(prefix.count)
            return !remainder.contains("::")
        }
    }

    // MARK: - Loading

    func loadInitial() async {
        await loadDecks()
        await performSearch()
        allTags = ((try? tagClient.getAllTags()) ?? []).sorted()
        if let pairs = try? notetypesService.getNotetypeNames() {
            notetypeNames = Dictionary(uniqueKeysWithValues: pairs.map { ($0.id, $0.name) })
        }
    }

    func loadDecks() async {
        do {
            allDecks = try deckClient.fetchAll()
        } catch {
            allDecks = []
        }
    }

    func performSearch() async {
        isLoading = true
        let query = buildQuery()
        do {
            let results = try noteClient.search(query, nil)
            allNotes = results
            notes = Array(results.prefix(pageSize))
            hasMorePages = results.count > pageSize
        } catch {
            allNotes = []
            notes = []
            hasMorePages = false
        }
        isLoading = false
    }

    func loadNextPage() async {
        guard hasMorePages, !isLoading else { return }
        let loaded = notes.count
        let nextBatch = Array(allNotes.dropFirst(loaded).prefix(pageSize))
        notes.append(contentsOf: nextBatch)
        hasMorePages = notes.count < allNotes.count
    }

    /// Lazy-fetch full note details for a stub and update the arrays in place.
    func fetchNoteDetails(id: NoteID) async {
        guard let fullNote = try? noteClient.fetch(id) else { return }
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx] = fullNote
        }
        if let idx = allNotes.firstIndex(where: { $0.id == id }) {
            allNotes[idx] = fullNote
        }
    }

    /// Resolve a possibly-stub note to its full record before navigation.
    func resolved(_ note: NoteRecord) -> NoteRecord {
        guard note.sfld == "Loading..." else { return note }
        return (try? noteClient.fetch(note.id)) ?? note
    }

    // MARK: - Mutations

    func delete(_ id: NoteID) async {
        try? noteClient.delete(id)
        await performSearch()
    }

    func suspendSelected(_ noteIDs: Set<NoteID>) async {
        for id in collectCardIDs(for: noteIDs) {
            try? cardClient.suspend(id)
        }
        await performSearch()
    }

    func flagSelected(_ noteIDs: Set<NoteID>, value: UInt32) async {
        for id in collectCardIDs(for: noteIDs) {
            try? cardClient.flag(id, value)
        }
        await performSearch()
    }

    func deleteSelected(_ noteIDs: Set<NoteID>) async {
        for id in noteIDs {
            try? noteClient.delete(id)
        }
        await performSearch()
    }

    // MARK: - Query

    func buildQuery() -> String {
        var parts: [String] = []
        if let deck = activeDeck {
            parts.append("deck:\"\(deck.name)\"")
        }
        if let tag = activeTag {
            parts.append("tag:\"\(tag)\"")
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        }
        return parts.joined(separator: " ")
    }

    private func collectCardIDs(for noteIDs: Set<NoteID>) -> [CardID] {
        var result: [CardID] = []
        for nid in noteIDs {
            if let cards = try? cardClient.fetchByNote(nid) {
                result.append(contentsOf: cards.map(\.id))
            }
        }
        return result
    }
}
