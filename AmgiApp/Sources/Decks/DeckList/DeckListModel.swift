import AmgiUI
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

    func load() async {
        do {
            let tree = try deckClient.fetchTree()
            if tree.isEmpty {
                state = .empty
                return
            }
            let rows = tree.map(DeckListRow.init(node:))
            let (hero, heatmap) = buildHeroAndHeatmap(rows: rows)
            state = .loaded(rows: rows.map(\.viewData), hero: hero, heatmap: heatmap)
        } catch {
            print("[DeckListModel] Error loading decks: \(error)")
            state = .empty
        }
    }

    func delete(_ id: DeckID) async {
        do {
            _ = try deckClient.delete(id)
        } catch {
            print("[DeckListModel] Delete failed: \(error)")
        }
        await load()
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
        var counts: [Int: Int] = [:]
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
    func buildHeroAndHeatmap(rows: [DeckListRow]) -> (HeroData, HeatmapCardData) {
        let totalDue = rows.reduce(0) { $0 + $1.counts.total }
        let deckCount = rows.count
        guard let graphs = try? statsClient.fetchGraphs("", 365) else {
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
            streak: StreakCalculator.streak(reviews: reviewCounts),
            last14Days: StreakCalculator.lastNDaysTotals(reviews: reviewCounts, days: 14)
        )
        return (hero, Self.buildHeatmap(reviews: reviewCounts))
    }
}
