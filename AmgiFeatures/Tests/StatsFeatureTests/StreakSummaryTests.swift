//
//  StreakSummaryTests.swift
//  StatsFeatureTests
//
//  Created by Vladimir Gusev on 18.09.2026.
//

import AnkiClients
import AnkiKit
import ConcurrencyExtras
import Dependencies
import StatsCharts
import Testing
@testable import StatsFeature

@MainActor
@Suite("Stats streak card")
struct StreakSummaryTests {

    private struct Boom: Error {}

    private func reviews(_ offsets: [Int: Int]) -> ReviewCountsAndTimes {
        var count: [Int: ReviewCountsAndTimes.Reviews] = [:]
        for (offset, n) in offsets {
            count[offset] = ReviewCountsAndTimes.Reviews(learn: n)
        }
        return ReviewCountsAndTimes(count: count)
    }

    @Test("the comparison is the last 30 active days against the 30 before them")
    func comparisonSpansTwoAdjacentMonths() {
        let r = reviews([0: 1, -1: 1, -2: 1, -10: 1, -29: 1, -30: 1, -59: 1])
        let summary = StreakSummary(reviews: r.count)

        #expect(summary.days == 3)          // -3 is missing, so the run stops
        #expect(summary.comparison == 3)    // 5 − 2
    }

    @Test("the streak fetch asks for its own window, not the period's")
    func streakFetchIgnoresThePeriod() async {
        let requested = LockIsolated<[Int]>([])
        let model = withDependencies {
            $0.statsClient = StatsClient { _, days in
                requested.withValue { $0.append(days) }
                return GraphsSnapshot()
            }
        } operation: {
            StatsDashboardModel()
        }

        await model.loadStats(search: "", days: StatsPeriod.day.days)
        await model.loadStreak(search: "")

        #expect(requested.value == [1, StreakSummary.window])
    }

    @Test("a failed streak fetch clears the card rather than leaving a stale streak")
    func failedFetchClearsTheStreak() async {
        let shouldThrow = LockIsolated(false)
        let model = withDependencies {
            $0.statsClient = StatsClient { _, _ in
                if shouldThrow.value { throw Boom() }
                return GraphsSnapshot(reviews: ReviewCountsAndTimes(
                    count: [0: ReviewCountsAndTimes.Reviews(learn: 4)]
                ))
            }
        } operation: {
            StatsDashboardModel()
        }

        await model.loadStreak(search: "")
        #expect(model.streak?.days == 1)

        shouldThrow.setValue(true)
        await model.loadStreak(search: "")
        #expect(model.streak == nil)
    }
}
