//
//  BrowseModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 22.06.2026.
//

import AppCore
import AnkiClients
import AnkiBackend
import AnkiKit
import AnkiServices
import Dependencies
import Foundation
import OSLog

/// Data state + load/search/mutation logic for the Browse screen. Mirrors
/// `DeckListModel`: the View owns navigation, sheets, selection, and the
/// toolbar, while the model owns I/O, paging, and query assembly so that
/// logic is testable in isolation and the View stays a thin presentation
/// wiring layer.
@Observable
@MainActor
final class BrowseModel {
    var searchText = ""
    /// Surfaced when a batch mutation partially or wholly fails.
    var errorMessage: String?
    var allNotes: [NoteRecord] = []
    var notes: [NoteRecord] = [] {
        didSet { if !isPatchingInPlace { resort() } }
    }
    /// Set only across `fetchNoteDetails`' single-element write. Filling a stub
    /// replaces one row's content without changing the list's membership, and
    /// re-sorting there ran a full sort *per row* as stubs filled during a
    /// scroll. Every other write to `notes` still re-sorts.
    private var isPatchingInPlace = false
    var allDecks: [DeckInfo] = []
    /// The top-level parent deck selected (stays set even when drilling into subdecks).
    var parentDeck: DeckInfo?
    /// The actual deck filter applied (could be parent or a subdeck).
    var activeDeck: DeckInfo?
    var isLoading = false
    /// True when the last search threw, so the empty state can say "search
    /// failed" rather than "no results".
    private(set) var searchFailed = false
    var hasMorePages = true
    var allTags: [String] = []
    var activeTag: String?
    var sortOrder: BrowseSortOrder = .dateDesc {
        didSet { resort() }
    }
    var notetypeNames: [NotetypeID: String] = [:] {
        didSet { if sortOrder == .templateAsc { resort() } }
    }

    /// First card of each note, resolved lazily by the row context menu.
    /// Cached here rather than in per-row `@State` so a row scrolling out and
    /// back doesn't re-issue the backend lookup.
    ///
    /// `@ObservationIgnored` on purpose: rows hold the resolved value in their
    /// own `@State` and reach this only through `firstCardID(for:)`. Observed,
    /// one row's entry landing would invalidate the menu button of every other
    /// row reading the dictionary — N writes fanning out to N rows on a scroll.
    @ObservationIgnored private var firstCardIDs: [NoteID: CardID] = [:]

    private let pageSize = 50

    @ObservationIgnored @Dependency(\.noteClient) private var noteClient
    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.cardClient) private var cardClient
    @ObservationIgnored @Dependency(\.tagClient) private var tagClient
    @ObservationIgnored @Dependency(\.notetypesService) private var notetypesService

    // MARK: - Derived

    /// Stored, not computed: `body` reads this on every pass, and a computed
    /// property would re-sort the whole loaded list each time — including once
    /// per row as `fetchNoteDetails` fills in stubs during a scroll.
    private(set) var sortedNotes: [NoteRecord] = []

    private func resort() {
        switch sortOrder {
        case .dateDesc:
            sortedNotes = notes.sorted { $0.mod > $1.mod }
        case .titleAsc:
            sortedNotes = notes.sorted {
                $0.sfld.localizedCaseInsensitiveCompare($1.sfld) == .orderedAscending
            }
        case .templateAsc:
            sortedNotes = notes.sorted { (notetypeNames[$0.mid] ?? "") < (notetypeNames[$1.mid] ?? "") }
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

    /// Everything the screen needs that isn't the note list itself. The list is
    /// driven separately by `.task(id: searchQuery)`, which also covers the
    /// first load — searching here too would issue the same query twice.
    func loadInitial() async {
        await loadDecks()
        allTags = ((try? await tagClient.getAllTags()) ?? []).sorted()
        let notetypes = notetypesService
        if let pairs = try? await backendOffload({ try notetypes.getNotetypeNames() }) {
            notetypeNames = Dictionary(uniqueKeysWithValues: pairs.map { ($0.id, $0.name) })
        }
    }

    func loadDecks() async {
        do {
            allDecks = try await deckClient.fetchAll()
        } catch {
            allDecks = []
        }
    }

    /// The full query the note list reflects. Drive `performSearch` from
    /// `.task(id: searchQuery)` so a change cancels the in-flight search
    /// instead of racing it.
    var searchQuery: String { buildQuery() }

    /// Runs the current query after a debounce.
    ///
    /// Both waits are cancellation points, and that is what makes this safe to
    /// re-enter: driven from `.task(id:)`, a superseded call is cancelled
    /// either during the sleep (so it never hits the backend) or before it can
    /// write results. Without those guards, typing "hello" issued five
    /// searches and the list showed whichever *returned* last.
    func performSearch(debounce: Duration = .milliseconds(250)) async {
        if debounce > .zero {
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
        }

        isLoading = true
        let query = buildQuery()
        do {
            let results = try await noteClient.search(query, nil)
            guard !Task.isCancelled else { return }
            searchFailed = false
            allNotes = results
            notes = Array(results.prefix(pageSize))
            hasMorePages = results.count > pageSize
        } catch {
            guard !Task.isCancelled else { return }
            // An empty list on failure is indistinguishable from "no matches",
            // so record the difference for the empty state to read.
            searchFailed = true
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
    ///
    /// Patches `sortedNotes` directly rather than re-sorting: a stub fill
    /// replaces one row's content without changing which notes are in the
    /// list, and re-sorting here ran a full sort per row filled during a
    /// scroll — under `.titleAsc` that also reordered rows under the user's
    /// finger mid-scroll.
    func fetchNoteDetails(id: NoteID) async {
        guard let fullNote = try? await noteClient.fetch(id) else { return }
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            isPatchingInPlace = true
            notes[idx] = fullNote
            isPatchingInPlace = false
        }
        if let idx = allNotes.firstIndex(where: { $0.id == id }) {
            allNotes[idx] = fullNote
        }
        if let idx = sortedNotes.firstIndex(where: { $0.id == id }) {
            sortedNotes[idx] = fullNote
        }
    }

    /// Resolves (once) the first card of a note, for the row context menu.
    /// Returns the cached value when it's already known, so a row scrolling
    /// out and back doesn't re-issue the lookup.
    func firstCardID(for noteId: NoteID) async -> CardID? {
        if let cached = firstCardIDs[noteId] { return cached }
        guard let cardId = (try? await cardClient.fetchByNote(noteId))?.first?.id else {
            return nil
        }
        firstCardIDs[noteId] = cardId
        return cardId
    }

    /// Resolve a possibly-stub note to its full record before navigation.
    /// This runs from a synchronous SwiftUI `navigationDestination` closure
    /// that can't await, so it falls back to the model's already-loaded
    /// arrays (kept current by `fetchNoteDetails`) rather than an async
    /// backend fetch.
    func resolved(_ note: NoteRecord) -> NoteRecord {
        guard note.sfld == "Loading..." else { return note }
        return notes.first(where: { $0.id == note.id })
            ?? allNotes.first(where: { $0.id == note.id })
            ?? note
    }

    // MARK: - Mutations

    func delete(_ id: NoteID) async {
        await runBatch("delete", over: [id]) { try await self.noteClient.delete($0) }
    }

    func suspendSelected(_ noteIDs: Set<NoteID>) async {
        let cardIDs = await collectCardIDs(for: noteIDs)
        await runBatch("suspend", over: cardIDs) { try await self.cardClient.suspend($0) }
    }

    func flagSelected(_ noteIDs: Set<NoteID>, value: UInt32) async {
        let cardIDs = await collectCardIDs(for: noteIDs)
        await runBatch("flag", over: cardIDs) { try await self.cardClient.flag($0, value) }
    }

    func deleteSelected(_ noteIDs: Set<NoteID>) async {
        await runBatch("delete", over: Array(noteIDs)) { try await self.noteClient.delete($0) }
    }

    /// Applies `work` to every id, counting failures rather than discarding
    /// them. These were `try?` per item, so in a multi-select batch an
    /// arbitrary subset could fail with zero feedback — the user believed
    /// 100 notes were deleted when some were not.
    private func runBatch<ID>(
        _ verb: String,
        over ids: [ID],
        _ work: (ID) async throws -> Void
    ) async {
        var failures = 0
        var firstError: String?
        for id in ids {
            do {
                try await work(id)
            } catch {
                failures += 1
                if firstError == nil { firstError = error.localizedDescription }
                Log.browse.error("Batch \(verb) failed for one item: \(error)")
            }
        }
        if failures > 0 {
            errorMessage = failures == ids.count
                ? "Couldn't \(verb) \(failures == 1 ? "that item" : "those \(failures) items"): \(firstError ?? "unknown error")"
                : "\(failures) of \(ids.count) items couldn't be \(verb)d: \(firstError ?? "unknown error")"
        }
        await performSearch()
    }

    // MARK: - Query

    func buildQuery() -> String {
        var parts: [String] = []
        if let deck = activeDeck {
            parts.append(DeckSearch.term(deck.name))
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

    private func collectCardIDs(for noteIDs: Set<NoteID>) async -> [CardID] {
        var result: [CardID] = []
        result.reserveCapacity(noteIDs.count)
        let cardClient = cardClient
        for nid in noteIDs {
            if let cards = try? await cardClient.fetchByNote(nid) {
                result.append(contentsOf: cards.map(\.id))
            }
        }
        return result
    }
}
