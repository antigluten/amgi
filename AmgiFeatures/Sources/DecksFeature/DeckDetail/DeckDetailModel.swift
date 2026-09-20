//
//  DeckDetailModel.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import OSLog
import AppCore
import Foundation
import AppShared
import UI
import AnkiKit
import AnkiClients
import Dependencies

/// Data state for the deck-detail screen. Action methods return their
/// outcome (error message / `Result`) instead of mutating presentation
/// flags — the Container translates those outcomes into `Destination`
/// transitions, keeping a single source of truth for what's on screen.
@Observable
@MainActor
final class DeckDetailModel {
    let deck: DeckInfo

    /// Flips true once the first `loadCounts()` resolves, so the screen
    /// can show `.loading` until then instead of inferring it from
    /// zero-valued data (which can't tell "empty deck" from "not loaded").
    private(set) var hasLoaded = false

    var counts: DeckCounts = .zero
    var childDecks: [DeckTreeNode] = []
    var statsSnapshot: DeckDetailStats.Snapshot?

    private(set) var cardTotal: Int?

    var isEmpty: Bool { Self.isEmpty(cardTotal: cardTotal, counts: counts, childDecks: childDecks) }

    static func isEmpty(cardTotal: Int?, counts: DeckCounts, childDecks: [DeckTreeNode]) -> Bool {
        if let cardTotal { return cardTotal == 0 }
        return counts.total == 0 && childDecks.isEmpty
    }

    var actionInFlight = false
    var feedback: String?
    var exportInProgress = false

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.statsClient) private var statsClient
    @ObservationIgnored @Dependency(\.collectionStore) private var store
    @ObservationIgnored private var statsTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    enum ExportOutcome {
        case success(URL)
        case failure(String)
    }

    init(deck: DeckInfo) {
        self.deck = deck
    }

    func loadCounts() async {
        do {
            counts = try await deckClient.countsForDeck(deck.id)
        } catch {
            Log.decks.error("Error loading counts for deck \(self.deck.id.rawValue): \(error)")
            counts = .zero
        }
        hasLoaded = true
    }

    func loadChildren() async {
        do {
            let tree = try await store.tree()
            childDecks = Self.findChildren(in: tree, parentId: deck.id)
        } catch {
            childDecks = []
        }
    }

    /// Fires the per-deck stats fetch off the main actor, cancels any
    /// in-flight call, and writes the projected snapshot back when done.
    /// The screen never blocks waiting for stats — counts render first.
    func loadStats() {
        statsTask?.cancel()
        let deckName = deck.name
        statsTask = Task { [weak self, statsClient] in
            // search syntax matches the Anki desktop "deck:" filter.
            let search = DeckSearch.term(deckName)
            let graphs = try? await statsClient.fetchGraphs(search, 30)
            guard !Task.isCancelled, let self else { return }
            if let graphs {
                self.cardTotal = graphs.cardCounts.includingInactive.total
                self.statsSnapshot = DeckDetailStats.project(graphs: graphs, isEmpty: self.isEmpty)
            } else {
                self.statsSnapshot = DeckDetailStats.Snapshot(
                    insights: .empty,
                    subtitle: self.isEmpty ? "No cards yet · Add some to start studying" : ""
                )
            }
        }
    }

    func showFeedback(_ text: String) {
        feedbackTask?.cancel()
        feedback = text
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.feedback = nil
        }
    }

    /// Returns nil on success; otherwise an error message to surface.
    func rebuild() async -> String? {
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            let count = try await deckClient.rebuildFilteredDeck(deck.id)
            showFeedback("Rebuilt — \(count) cards")
            // Rebuild's request only decodes a count — invalidate conservatively.
            store.apply(CollectionChanges(card: true, deck: true, studyQueues: true))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Returns nil on success; otherwise an error message to surface.
    func empty() async -> String? {
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            try await deckClient.emptyFilteredDeck(deck.id)
            store.apply(CollectionChanges(card: true, deck: true, studyQueues: true))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Raises today's new *or* review limit for this deck. Returns nil on
    /// success; otherwise an error message to surface.
    func extendLimit(_ kind: DeckLimitKind, by delta: Int32) async -> String? {
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            try await deckClient.extendLimits(
                deck.id,
                kind == .new ? delta : 0,
                kind == .review ? delta : 0
            )
            store.apply(CollectionChanges(deck: true, studyQueues: true))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func exportDeck() async -> ExportOutcome {
        exportInProgress = true
        defer { exportInProgress = false }
        do {
            let deckId = deck.id
            let deckName = deck.name
            let url = try await Task.detached {
                try ImportHelper.exportDeck(deckId: deckId, deckName: deckName)
            }.value
            return .success(url)
        } catch {
            return .failure("Failed to export deck: \(error.localizedDescription)")
        }
    }

    /// Returns nil on success; otherwise an error message to surface.
    func createSubdeck(rawName: String) async -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Name cannot be empty." }
        // Anki uses :: as the deck-hierarchy separator. Strip any user-supplied
        // separator collisions to avoid creating multi-level decks unexpectedly.
        let leafName = trimmed.replacingOccurrences(of: "::", with: "_")
        let fullName = "\(deck.name)::\(leafName)"
        do {
            let creation = try await deckClient.create(fullName)
            store.apply(creation.changes)
            return nil
        } catch {
            return "Failed to create subdeck: \(error.localizedDescription)"
        }
    }
}

private extension DeckDetailModel {
    static func findChildren(in nodes: [DeckTreeNode], parentId: DeckID) -> [DeckTreeNode] {
        for node in nodes {
            if node.id == parentId { return node.children }
            let found = findChildren(in: node.children, parentId: parentId)
            if !found.isEmpty { return found }
        }
        return []
    }

}
