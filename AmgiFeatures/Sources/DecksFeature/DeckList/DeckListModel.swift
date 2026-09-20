//
//  DeckListModel.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 13.06.2026.
//

import OSLog
import UI
import AppCore
import AppShared
import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Data state + load/mutation logic for the Library screen. Mirrors
/// `DeckDetailModel`: the View owns navigation, sheets, and the toolbar,
/// while the model owns I/O and the engine → view-data assembly so that
/// assembly is testable in isolation and the View stays a thin
/// presentation wiring layer.
@Observable
@MainActor
final class DeckListModel {
    var state: LibraryListContent.State = .loading

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.statsClient) private var statsClient
    @ObservationIgnored @Dependency(\.collectionStore) private var store

    /// Two phase, deliberately. The deck rows and the hero's due counts come
    /// straight from the deck tree; the streak, sparkline, and heatmap need a
    /// 365-day revlog scan. Publishing both together meant the primary content
    /// waited on the secondary — a blank screen at launch on a large
    /// collection. Rows go out first, activity fills in.
    func load() async {
        await AppSignpost.measure("DeckListLoad") { await loadBody() }
    }

    private func loadBody() async {
        // Carry the previous activity data through a refresh rather than
        // flashing placeholders over numbers that are still on screen.
        let carried: (hero: HeroData, heatmap: HeatmapCardData?)?
        if case .loaded(_, let hero, let heatmap) = state {
            carried = (hero, heatmap)
        } else {
            carried = nil
        }

        do {
            // Separates engine wait from Swift assembly. Phase one measured
            // 145 ms in-app but only 0.44 ms against stubbed clients
            // (DeckListLoadPerformanceTests), so the cost has to be in here —
            // and it is I/O-bound, which is why the CPU profile barely sees it.
            let tree = try await AppSignpost.measure("DeckTreeFetch") {
                try await store.tree()
            }
            if tree.isEmpty {
                state = .empty
                return
            }
            let rows = tree.map(DeckListRow.init(node:))
            let viewRows = rows.map(\.viewData)

            state = .loaded(
                rows: viewRows,
                hero: HeroData(
                    totalDue: rows.reduce(0) { $0 + $1.counts.total },
                    deckCount: rows.count,
                    streak: carried?.hero.streak ?? 0,
                    last14Days: carried?.hero.last14Days ?? Array(repeating: 0, count: 14)
                ),
                heatmap: carried?.heatmap
            )

            // Nested inside DeckListLoad on purpose: phase one (the deck
            // tree) and phase two (a 365-day revlog scan) have very
            // different costs, and a single interval hides which one the
            // launch path is actually waiting on.
            let (hero, heatmap) = await AppSignpost.measure("DeckListActivity") {
                await buildHeroAndHeatmap(rows: rows)
            }
            guard !Task.isCancelled else { return }
            state = .loaded(rows: viewRows, hero: hero, heatmap: heatmap)
        } catch {
            Log.decks.error("Error loading decks: \(error)")
            // NOT .empty — that is the genuine no-decks state, and rendering a
            // failure as it told users with a full collection they had none.
            state = .failed(error.localizedDescription)
        }
    }

    func delete(_ id: DeckID) async {
        do {
            let changes = try await deckClient.delete(id)
            store.apply(changes)   // generation bump → the view's .task(id:) reloads
        } catch {
            Log.decks.error("Delete failed: \(error)")
            await load()           // error path: no invalidation happened, reload manually
        }
    }

    /// First loaded deck that has cards waiting, projected to a `DeckInfo`
    /// for navigation. Nil while loading/empty or when nothing is due.
    func firstReviewableDeck() -> DeckInfo? {
        guard case .loaded(let rows, _, _) = state else { return nil }
        return rows.first(where: { $0.totalCount > 0 })?.asDeckInfo
    }

    static func buildHeatmap(
        reviews: [Int: ReviewCountsAndTimes.Reviews]
    ) -> HeatmapCardData {
        var counts = [Int: Int](minimumCapacity: min(reviews.count, 365))
        var maxCount = 1
        for (offset, rev) in reviews where offset >= -364 && offset <= 0 {
            let total = rev.learn + rev.relearn + rev.young + rev.mature + rev.filtered
            if total > 0 {
                counts[offset] = total
                if total > maxCount { maxCount = total }
            }
        }
        return HeatmapCardData(counts: counts, maxCount: maxCount)
    }
}

private extension DeckListModel {
    func buildHeroAndHeatmap(rows: [DeckListRow]) async -> (HeroData, HeatmapCardData) {
        let totalDue = rows.reduce(0) { $0 + $1.counts.total }
        let deckCount = rows.count
        // Window the streak over the same range we fetch, or the default
        // 28 silently caps a year's worth of data at 28 days.
        let graphDays = 365
        guard let graphs = try? await statsClient.fetchGraphs("", graphDays) else {
            return (
                HeroData(
                    totalDue: totalDue,
                    deckCount: deckCount,
                    streak: 0,
                    last14Days: Array(repeating: 0, count: 14)
                ),
                HeatmapCardData.empty
            )
        }
        let reviewCounts = graphs.reviews.count
        let hero = HeroData(
            totalDue: totalDue,
            deckCount: deckCount,
            streak: StreakCalculator.streak(reviews: reviewCounts, window: graphDays),
            last14Days: StreakCalculator.lastNDaysTotals(reviews: reviewCounts, days: 14)
        )
        return (hero, Self.buildHeatmap(reviews: reviewCounts))
    }
}
