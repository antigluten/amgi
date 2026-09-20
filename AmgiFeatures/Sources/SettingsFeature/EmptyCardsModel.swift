//
//  EmptyCardsModel.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 18.08.2026.
//

import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies
import Foundation

/// Data state + load/delete logic for the Empty Cards maintenance screen.
/// The View owns navigation, alerts, and the note-editor sheets; the model
/// owns the backend report scan, per-note deck resolution, and card removal
/// so the heavy work stays testable and off the View.
@Observable
@MainActor
final class EmptyCardsModel {
    var isLoading = true
    var report: String = ""
    var noteEntries: [NoteEntry] = []
    var isDeletingAll = false

    @ObservationIgnored @Dependency(\.cardRenderingService) private var cardRenderingService
    @ObservationIgnored @Dependency(\.cardClient) private var cardClient
    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.noteClient) private var noteClient

    struct NoteEntry: Identifiable {
        let id: NoteID
        let cardIds: [CardID]
        let totalCards: Int
        let emptyCards: Int
        let deckName: String
        let willDeleteNote: Bool
    }

    var totalEmptyCards: Int {
        noteEntries.reduce(0) { $0 + $1.cardIds.count }
    }

    func loadEmptyCards() async throws {
        let cardRenderingServiceCapture = cardRenderingService
        let capturedCardClient = cardClient
        let capturedDeckClient = deckClient
        defer { isLoading = false }
        // Build the full report + per-note entries off the main actor —
        // fetchAll() and the per-note fetchByNote() loop are synchronous
        // backend calls that scale with note count.
        let (reportText, entries) = try await Task.detached {
            let emptyReport = try cardRenderingServiceCapture.getEmptyCardsReport()
            let deckById = (try? await capturedDeckClient.fetchAll())?.reduce(into: [DeckID: String]()) { partial, deck in
                partial[deck.id] = deck.name
            } ?? [:]
            var entries: [NoteEntry] = []
            entries.reserveCapacity(emptyReport.notes.count)
            for note in emptyReport.notes {
                let cards = (try? await capturedCardClient.fetchByNote(note.noteID)) ?? []
                let totalCards = max(cards.count, note.cardIDs.count)
                let deckName = cards.first.flatMap { deckById[$0.did] } ?? "-"
                entries.append(NoteEntry(
                    id: note.noteID,
                    cardIds: note.cardIDs,
                    totalCards: totalCards,
                    emptyCards: note.cardIDs.count,
                    deckName: deckName,
                    willDeleteNote: note.willDeleteNote
                ))
            }
            return (emptyReport.report, entries)
        }.value
        report = reportText
        noteEntries = entries
    }

    /// Removes every empty card. Throws the backend failure so the View can
    /// route it to its `.error` destination.
    func deleteAllEmpty() async throws {
        isDeletingAll = true
        defer { isDeletingAll = false }
        let allCardIds = noteEntries.flatMap { $0.cardIds }
        let cardClientCapture = cardClient
        try await Task.detached {
            try await cardClientCapture.removeCards(allCardIds)
        }.value
    }

    /// Fetch the full note record for the editor; nil if the note is gone.
    func fetchNote(_ id: NoteID) async throws -> NoteRecord? {
        try await noteClient.fetch(id)
    }
}
