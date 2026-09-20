//
//  WriteWidgetSnapshot.swift
//  AppShared
//
//  Created by Vladimir Gusev on 07.04.2026.
//

import OSLog
import AppCore
import AnkiClients
import AnkiKit
import Dependencies
import Foundation
import WidgetKit

/// Fetches current deck data + streak, writes per-deck snapshot files to the
/// App Group container, then signals WidgetKit to reload all timelines.
/// Safe to call from any async context.
public func writeWidgetSnapshot() async {
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
        let decks: [DeckInfo] = try await deckClient.fetchAll()

        // Sweep in a defer so it still runs when a later step throws.
        // As the last statement of the `do` it was skipped entirely on any
        // failure, leaving the *previous* profile's deck names and due
        // counts in the shared container to keep rendering on the lock
        // screen after a profile switch.
        defer {
            WidgetSnapshotStore.removeSnapshots(notIn: Set([0] + decks.map(\.id.rawValue)))
            WidgetCenter.shared.reloadAllTimelines()
        }

        // 2. Fetch 28-day stats graph for streak + daily counts
        let graphs = try await statsClient.fetchGraphs("", 28)

        // 3+4. Compute streak and last-7-days totals via shared helper.
        let streak = StreakCalculator.streak(reviews: graphs.reviews.count)
        let lastSevenDays = StreakCalculator.lastNDaysTotals(
            reviews: graphs.reviews.count, days: 7
        )

        let reviewedToday = graphs.today.answerCount
        let now = Date()
        let rolloverHour = graphs.rolloverHour
        let dayZero = AnkiDay.start(of: now, rolloverHour: rolloverHour)

        // 5. Write all-decks aggregate snapshot (deckId = 0)
        let aggregateBase = WidgetSnapshot.DayCounts(
            newCount: decks.reduce(0) { $0 + $1.counts.newCount },
            learnCount: decks.reduce(0) { $0 + $1.counts.learnCount },
            reviewCount: decks.reduce(0) { $0 + $1.counts.reviewCount }
        )
        let allDecksSnapshot = WidgetSnapshot(
            deckId: 0,
            deckName: "All Decks",
            newCount: aggregateBase.newCount,
            learnCount: aggregateBase.learnCount,
            reviewCount: aggregateBase.reviewCount,
            reviewedToday: reviewedToday,
            streak: streak,
            lastSevenDays: lastSevenDays,
            snapshotDate: now,
            forecast: WidgetSnapshot.Forecast(
                rolloverHour: rolloverHour,
                dayZero: dayZero,
                days: forecastDays(base: aggregateBase, futureDue: graphs.futureDue.futureDue),
                futureDue: graphs.futureDue.futureDue
            )
        )
        try WidgetSnapshotStore.write(allDecksSnapshot)

        // 6. Write per-deck snapshots. Each deck needs its own future-due
        // histogram for the forecast; a failed per-deck fetch degrades to a
        // forecast-less snapshot rather than failing the whole write.
        //
        // The engine's graphs RPC takes one search string, so there is no
        // batch form without a new proto method — but a forecast is a
        // projection over whole Anki days, so recomputing it mid-day is
        // wasted work. Counts below come from the already-fetched deck list
        // and still update on every foreground; only the forecast is reused
        // when the stored one was written in the current Anki day. That
        // turns N RPCs per foreground into N once a day.
        for deck in decks {
            let base = WidgetSnapshot.DayCounts(
                newCount: deck.counts.newCount,
                learnCount: deck.counts.learnCount,
                reviewCount: deck.counts.reviewCount
            )
            let storedForecast = WidgetSnapshotStore.read(deckId: deck.id.rawValue)?.forecast
            let forecastIsCurrent = storedForecast.map {
                $0.rolloverHour == rolloverHour && $0.dayZero == dayZero
            } ?? false
            let deckFutureDue: [Int: Int]?
            if forecastIsCurrent, let reusable = storedForecast?.futureDue {
                // Same Anki day: re-project the stored histogram against the
                // deck's current counts rather than re-fetching it.
                deckFutureDue = reusable
            } else {
                deckFutureDue = (try? await statsClient.fetchGraphs(deckSearch(deck.name), 1))?
                    .futureDue.futureDue
            }
            let snapshot = WidgetSnapshot(
                deckId: deck.id.rawValue,
                deckName: deck.name,
                newCount: base.newCount,
                learnCount: base.learnCount,
                reviewCount: base.reviewCount,
                reviewedToday: reviewedToday,
                streak: streak,
                lastSevenDays: lastSevenDays,
                snapshotDate: now,
                forecast: deckFutureDue.map { futureDue in
                    WidgetSnapshot.Forecast(
                        rolloverHour: rolloverHour,
                        dayZero: dayZero,
                        days: forecastDays(base: base, futureDue: futureDue),
                        futureDue: futureDue
                    )
                }
            )
            try WidgetSnapshotStore.write(snapshot)
        }

        // 7+8. Sweep + timeline reload happen in the defer above.
    } catch {
        Log.widget.error("Failed: \(error)")
    }
}

/// Due counts for the write day plus the next `horizon` Anki-days, assuming
/// no reviews happen in between: unfinished learn/review cards carry over,
/// and each day adds its future-due bucket.
private func forecastDays(
    base: WidgetSnapshot.DayCounts,
    futureDue: [Int: Int],
    horizon: Int = 7
) -> [WidgetSnapshot.DayCounts] {
    var days = [base]
    var carriedReviews = base.learnCount + base.reviewCount
    for day in 1...horizon {
        carriedReviews += futureDue[day] ?? 0
        // ponytail: future newCount = today's remaining new; ignores the
        // daily new-limit reset. Upgrade path: surface the deck's new/day
        // limit through DeckInfo if the approximation ever bothers anyone.
        days.append(WidgetSnapshot.DayCounts(
            newCount: base.newCount,
            learnCount: 0,
            reviewCount: carriedReviews
        ))
    }
    return days
}

/// Anki search string matching one deck (and its subdecks) by name.
private func deckSearch(_ name: String) -> String {
    DeckSearch.term(name)
}
