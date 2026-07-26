import Foundation
import AmgiUI
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

    var actionInFlight = false
    var rebuildFeedback: String?
    var exportInProgress = false
    var importInProgress = false

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.statsClient) private var statsClient
    @ObservationIgnored private var statsTask: Task<Void, Never>?

    enum ImportOutcome {
        case success(String)
        case failure(String)
    }

    enum ExportOutcome {
        case success(URL)
        case failure(String)
    }

    init(deck: DeckInfo) {
        self.deck = deck
    }

    func loadCounts() async {
        do {
            counts = try deckClient.countsForDeck(deck.id)
        } catch {
            print("[DeckDetail] Error loading counts for '\(deck.name)': \(error)")
            counts = .zero
        }
        hasLoaded = true
    }

    func loadChildren() async {
        do {
            let tree = try deckClient.fetchTree()
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
        let isEmpty = counts.total == 0 && childDecks.isEmpty
        statsTask = Task { [weak self, statsClient] in
            // search syntax matches the Anki desktop "deck:" filter.
            let search = "deck:\"\(deckName)\""
            let graphs = try? await Task.detached(priority: .userInitiated) {
                try statsClient.fetchGraphs(search, 30)
            }.value
            guard !Task.isCancelled, let self else { return }
            if let graphs {
                self.statsSnapshot = DeckDetailStats.project(graphs: graphs, isEmpty: isEmpty)
            } else {
                self.statsSnapshot = DeckDetailStats.Snapshot(
                    insights: .empty,
                    subtitle: isEmpty ? "No cards yet · Add some to start studying" : ""
                )
            }
        }
    }

    /// Returns nil on success; otherwise an error message to surface.
    func rebuild() async -> String? {
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            let count = try deckClient.rebuildFilteredDeck(deck.id)
            rebuildFeedback = "Rebuilt — \(count) cards"
            await loadCounts()
            try? await Task.sleep(for: .seconds(2))
            rebuildFeedback = nil
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
            try deckClient.emptyFilteredDeck(deck.id)
            await loadCounts()
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

    func handleImport(_ result: Result<URL, Error>) async -> ImportOutcome {
        switch result {
        case .success(let url):
            let ext = url.pathExtension.lowercased()
            guard ext == "apkg" || ext == "colpkg" else {
                return .failure("Unsupported file type. Please select an .apkg or .colpkg file.")
            }
            return await runImport(from: url)
        case .failure(let error):
            return .failure("Could not select file: \(error.localizedDescription)")
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
            _ = try deckClient.create(fullName)
            await loadChildren()
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

    func runImport(from url: URL) async -> ImportOutcome {
        importInProgress = true
        defer { importInProgress = false }
        do {
            let summary = try await Task.detached {
                try ImportHelper.importPackage(from: url)
            }.value
            await loadCounts()
            await loadChildren()
            return .success(summary)
        } catch {
            return .failure("Import failed: \(error.localizedDescription)")
        }
    }
}
