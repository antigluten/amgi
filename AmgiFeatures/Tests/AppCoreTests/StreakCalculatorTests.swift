//
//  StreakCalculatorTests.swift
//  AppCoreTests
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import Testing
import AnkiKit
@testable import AppCore

@Suite struct StreakCalculatorTests {
    private func reviews(_ offsets: [Int: Int]) -> [Int: ReviewCountsAndTimes.Reviews] {
        var out: [Int: ReviewCountsAndTimes.Reviews] = [:]
        for (offset, n) in offsets {
            out[offset] = ReviewCountsAndTimes.Reviews(
                learn: n, relearn: 0, young: 0, mature: 0, filtered: 0
            )
        }
        return out
    }

    @Test func emptyMapReturnsZero() {
        #expect(StreakCalculator.streak(reviews: [:]) == 0)
    }

    @Test func consecutiveFromTodayCountsAllDays() {
        let r = reviews([0: 5, -1: 3, -2: 1])
        #expect(StreakCalculator.streak(reviews: r) == 3)
    }

    @Test func todayEmptyYesterdayFullCountsFromYesterday() {
        let r = reviews([-1: 4, -2: 2, -3: 1])
        #expect(StreakCalculator.streak(reviews: r) == 3)
    }

    @Test func gapStopsTheCount() {
        let r = reviews([0: 5, -1: 3, -3: 1]) // missing -2
        #expect(StreakCalculator.streak(reviews: r) == 2)
    }

    @Test func bothTodayAndYesterdayEmptyReturnsZero() {
        let r = reviews([-2: 5, -3: 3])
        #expect(StreakCalculator.streak(reviews: r) == 0)
    }

    @Test func windowLimitsLookback() {
        // 30 consecutive days but window is 5
        var offsets: [Int: Int] = [:]
        for i in 0...29 { offsets[-i] = 1 }
        #expect(StreakCalculator.streak(reviews: reviews(offsets), window: 5) == 5)
    }

    @Test func lastNDaysReturnsCorrectLength() {
        let r = reviews([0: 5, -1: 3, -2: 1])
        let totals = StreakCalculator.lastNDaysTotals(reviews: r, days: 14)
        #expect(totals.count == 14)
    }

    @Test func lastNDaysOrderedOldestToNewest() {
        let r = reviews([0: 100, -1: 50, -2: 25])
        let totals = StreakCalculator.lastNDaysTotals(reviews: r, days: 3)
        #expect(totals == [25, 50, 100])
    }

    @Test func lastNDaysZeroFillsMissingOffsets() {
        let r = reviews([0: 5, -2: 1]) // -1 missing
        let totals = StreakCalculator.lastNDaysTotals(reviews: r, days: 3)
        #expect(totals == [1, 0, 5])
    }

    @Test func activeDaysCountsGappedDays() {
        // A streak would stop at the -2 gap; active days does not.
        let r = reviews([0: 5, -1: 3, -3: 1, -4: 2])
        #expect(StreakCalculator.activeDays(reviews: r, in: -29...0) == 4)
    }

    @Test func activeDaysIgnoresOffsetsOutsideTheWindow() {
        let r = reviews([0: 5, -30: 9, -45: 9])
        #expect(StreakCalculator.activeDays(reviews: r, in: -29...0) == 1)
        #expect(StreakCalculator.activeDays(reviews: r, in: -59...(-30)) == 2)
    }

    @Test func activeDaysTreatsAZeroDayAsInactive() {
        // The engine can return a day whose buckets are all zero; it is not
        // an active day, and counting the key would inflate every comparison.
        let r = reviews([0: 0, -1: 4])
        #expect(StreakCalculator.activeDays(reviews: r, in: -29...0) == 1)
    }
}
