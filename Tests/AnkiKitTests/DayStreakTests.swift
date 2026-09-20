//
//  DayStreakTests.swift
//  AnkiKitTests
//
//  Created by Vladimir Gusev on 20.08.2026.
//

import Testing
@testable import AnkiKit

/// `DayStreak` is the single streak algorithm shared by the Library hero card
/// (via `StreakCalculator`) and the Stats heatmap. Before it existed those
/// were separate implementations that could disagree about the same user.
@Suite("Day streak")
struct DayStreakTests {
    @Test("counts consecutive days back from today")
    func countsFromToday() {
        #expect(DayStreak.count(totals: [0: 3, -1: 1, -2: 5], window: 28) == 3)
    }

    @Test("an empty today doesn't break a streak that ran through yesterday")
    func emptyTodayStartsAtYesterday() {
        #expect(DayStreak.count(totals: [0: 0, -1: 2, -2: 2], window: 28) == 2)
    }

    @Test("stops at the first gap")
    func stopsAtGap() {
        #expect(DayStreak.count(totals: [0: 1, -1: 0, -2: 9], window: 28) == 1)
    }

    @Test("no data is a zero streak")
    func empty() {
        #expect(DayStreak.count(totals: [:], window: 28) == 0)
    }

    @Test("the window caps the result")
    func windowCaps() {
        // Regression for §5.3: the deck list fetches 365 days but used to
        // pass the default 28, silently capping every streak.
        let year = Dictionary(uniqueKeysWithValues: (0...364).map { (-$0, 1) })
        #expect(DayStreak.count(totals: year, window: 28) == 28)
        #expect(DayStreak.count(totals: year, window: 365) == 365)
    }

    @Test("a non-positive window yields zero rather than trapping")
    func nonPositiveWindow() {
        #expect(DayStreak.count(totals: [0: 5], window: 0) == 0)
    }
}
