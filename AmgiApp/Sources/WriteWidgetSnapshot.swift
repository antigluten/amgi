// AmgiApp/Sources/WriteWidgetSnapshot.swift
import AnkiClients
import AnkiKit
import AnkiProto
import Dependencies
import Foundation
import SwiftProtobuf
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
        let graphData: Data = try statsClient.fetchGraphs("", 28)
        let graphs = try Anki_Stats_GraphsResponse(serializedBytes: graphData)

        // Helper to total all review types for a day
        func dayTotal(_ rev: Anki_Stats_GraphsResponse.ReviewCountsAndTimes.Reviews) -> Int {
            Int(rev.learn) + Int(rev.relearn) + Int(rev.young) + Int(rev.mature) + Int(rev.filtered)
        }

        // 3. Calculate streak: count consecutive days backward from today
        // Start from today; if today is empty, start from yesterday (may still review later)
        let todayTotal = graphs.reviews.count[Int32(0)].map { dayTotal($0) } ?? 0
        let startOffset = todayTotal > 0 ? Int32(0) : Int32(-1)

        var streak = 0
        for offset in stride(from: startOffset, through: Int32(-27), by: -1) {
            guard let rev = graphs.reviews.count[offset] else { break }
            guard dayTotal(rev) > 0 else { break }
            streak += 1
        }

        // 4. Build last-7-days array (index 0 = 6 days ago, index 6 = today)
        let lastSevenDays: [Int] = (-6 ... 0).map { offset in
            guard let rev = graphs.reviews.count[Int32(offset)] else { return 0 }
            return dayTotal(rev)
        }

        let reviewedToday = Int(graphs.today.answerCount)
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
                deckId: deck.id,
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
