// AmgiApp/Sources/WriteWidgetSnapshot.swift
import AnkiClients
import AnkiKit
import Dependencies
import Foundation
import WidgetKit

/// Fetches current deck data + streak, writes per-deck snapshot files to the
/// App Group container, then signals WidgetKit to reload all timelines.
/// Safe to call from any async context.
func writeWidgetSnapshot() async {
    // Skip during XCTest runs — the lifecycle hooks that call this run inside
    // the host app's scene phase / didFinishLaunching, which fire even when
    // the app is hosting a test bundle. Calling unimplemented dependency stubs
    // there registers as a test failure even though the caller catches the
    // error. Tests that genuinely need widget-snapshot behavior can call this
    // directly inside their own withDependencies overrides.
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return
    }

    @Dependency(\.deckClient) var deckClient
    @Dependency(\.statsClient) var statsClient

    do {
        // 1. Fetch deck list
        let decks: [DeckInfo] = try deckClient.fetchAll()

        // 2. Fetch 28-day stats graph for streak + daily counts
        let graphs = try statsClient.fetchGraphs("", 28)

        // 3+4. Compute streak and last-7-days totals via shared helper.
        let streak = StreakCalculator.streak(reviews: graphs.reviews.count)
        let lastSevenDays = StreakCalculator.lastNDaysTotals(
            reviews: graphs.reviews.count, days: 7
        )

        let reviewedToday = graphs.today.answerCount
        let now = Date()

        // 5. Write all-decks aggregate snapshot (deckId = 0)
        let allDecksSnapshot = WidgetSnapshot(
            deckId: 0,
            deckName: "All Decks",
            newCount: decks.reduce(0) { $0 + $1.counts.newCount },
            learnCount: decks.reduce(0) { $0 + $1.counts.learnCount },
            reviewCount: decks.reduce(0) { $0 + $1.counts.reviewCount },
            reviewedToday: reviewedToday,
            streak: streak,
            lastSevenDays: lastSevenDays,
            snapshotDate: now
        )
        try WidgetSnapshotStore.write(allDecksSnapshot)

        // 6. Write per-deck snapshots
        for deck in decks {
            let snapshot = WidgetSnapshot(
                deckId: deck.id.rawValue,
                deckName: deck.name,
                newCount: deck.counts.newCount,
                learnCount: deck.counts.learnCount,
                reviewCount: deck.counts.reviewCount,
                reviewedToday: reviewedToday,
                streak: streak,
                lastSevenDays: lastSevenDays,
                snapshotDate: now
            )
            try WidgetSnapshotStore.write(snapshot)
        }

        // 7. Tell WidgetKit to reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    } catch {
        print("[writeWidgetSnapshot] Failed: \(error)")
    }
}
