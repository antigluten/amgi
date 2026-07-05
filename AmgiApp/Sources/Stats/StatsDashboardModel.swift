import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Statistics-graph I/O for the stats dashboard. Owns the stats + deck
/// clients and the loaded graphs/deck list plus load state, so the view
/// carries no `@Dependency`; the period and selected-deck filter state stays
/// on the view and is passed into `loadStats`.
@Observable
@MainActor
final class StatsDashboardModel {
    var graphs: GraphsSnapshot?
    var isLoading = true
    var errorMessage: String?
    var decks: [DeckInfo] = []

    @ObservationIgnored @Dependency(\.statsClient) private var statsClient
    @ObservationIgnored @Dependency(\.deckClient) private var deckClient

    func loadDecks() async {
        decks = (try? await deckClient.fetchAll()) ?? []
    }

    func loadStats(search: String, days: Int) async {
        isLoading = graphs == nil
        do {
            graphs = try await statsClient.fetchGraphs(search, days)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
