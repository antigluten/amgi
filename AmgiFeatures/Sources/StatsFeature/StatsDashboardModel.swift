//
//  StatsDashboardModel.swift
//  StatsFeature
//
//  Created by Vladimir Gusev on 27.06.2026.
//

import AppCore
import AnkiClients
import AnkiKit
import Dependencies
import Foundation

@Observable
@MainActor
final class StatsDashboardModel {
    var state: StatsDashboardContent.State = .loading
    private(set) var isRefreshing = false
    var decks: [DeckInfo] = [] {
        didSet { topLevelDecks = decks.filter { !$0.name.contains("::") } }
    }

    private(set) var topLevelDecks: [DeckInfo] = []

    private(set) var streak: StreakSummary?

    @ObservationIgnored @Dependency(\.statsClient) private var statsClient
    @ObservationIgnored @Dependency(\.deckClient) private var deckClient

    func loadDecks() async {
        decks = (try? await deckClient.fetchAll()) ?? []
    }

    func loadStreak(search: String) async {
        guard let graphs = try? await statsClient.fetchGraphs(search, StreakSummary.window) else {
            streak = nil
            return
        }
        guard !Task.isCancelled else { return }
        streak = StreakSummary(reviews: graphs.reviews.count)
    }

    func loadStats(search: String, days: Int) async {
        await AppSignpost.measure("StatsLoad") { await loadStatsBody(search: search, days: days) }
    }

    private func loadStatsBody(search: String, days: Int) async {
        if case .loaded = state { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }
        do {
            let graphs = try await statsClient.fetchGraphs(search, days)
            guard !Task.isCancelled else { return }
            state = .loaded(graphs)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
