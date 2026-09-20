//
//  StatsDashboardView.swift
//  StatsFeature
//
//  Created by Vladimir Gusev on 10.08.2026.
//

package import SwiftUI
import Theme
import UI
import StatsCharts
import AnkiKit
import AnkiClients
import Dependencies

package struct StatsDashboardView: View {
    @Environment(\.palette) private var palette

    private let refreshID: UUID?

    @State private var model = StatsDashboardModel()
    @State private var period: StatsPeriod = .month
    @State private var selectedDeck: DeckInfo?

    package init(refreshID: UUID? = nil) {
        self.refreshID = refreshID
    }

    package var body: some View {
        StatsDashboardContent(
            state: model.state,
            period: period,
            selectedDeck: selectedDeck,
            topLevelDecks: model.topLevelDecks,
            onSelectDeck: { selectedDeck = $0 },
            onSelectPeriod: { period = $0 },
            onRetry: { Task { await reloadStats() } },
            streak: model.streak,
            isRefreshing: model.isRefreshing
        )
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("Statistics")
        .task(id: refreshID) { await model.loadDecks() }
        .task(id: query) { await reloadStats() }
        .task(id: streakQuery) { await model.loadStreak(search: search) }
        .refreshable {
            await reloadStats()
            await model.loadStreak(search: search)
        }
    }
}

private struct StatsQuery: Equatable {
    let refreshID: UUID?
    let periodDays: Int
    let deckName: String?
}

private struct StreakQuery: Equatable {
    let refreshID: UUID?
    let deckName: String?
}

private extension StatsDashboardView {
    var query: StatsQuery {
        StatsQuery(
            refreshID: refreshID,
            periodDays: period.days,
            deckName: selectedDeck?.name
        )
    }

    var streakQuery: StreakQuery {
        StreakQuery(refreshID: refreshID, deckName: selectedDeck?.name)
    }

    var search: String {
        selectedDeck.map { DeckSearch.term($0.name) } ?? ""
    }

    func reloadStats() async {
        await model.loadStats(search: search, days: period.days)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let _ = prepareDependencies {
        $0.statsClient = .previewValue
        $0.deckClient = .previewValue
    }
    NavigationStack {
        StatsDashboardView()
    }
}
#endif
