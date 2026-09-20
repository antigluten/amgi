//
//  ActivityHeatmapTests.swift
//  UITests
//
//  Created by Vladimir Gusev on 15.05.2026.
//

import Foundation
import Testing
import Theme
@testable import UI

@Suite("HeatmapCardData")
struct HeatmapCardDataTests {

    @Test("empty fixture has no counts and maxCount of 1")
    func emptyFixture() {
        let data = HeatmapCardData.empty
        #expect(data.counts.isEmpty)
        #expect(data.maxCount == 1)
    }

    @Test("maxCount clamps to 1 when zero is passed")
    func maxCountClampZero() {
        let data = HeatmapCardData(counts: [-1: 5], maxCount: 0)
        #expect(data.maxCount == 1)
    }

    @Test("maxCount clamps to 1 when negative is passed")
    func maxCountClampNegative() {
        let data = HeatmapCardData(counts: [-1: 5], maxCount: -3)
        #expect(data.maxCount == 1)
    }

    @Test("counts round-trips through init")
    func countsRoundTrip() {
        let data = HeatmapCardData(counts: [-1: 5, -3: 12], maxCount: 12)
        #expect(data.counts[-1] == 5)
        #expect(data.counts[-3] == 12)
        #expect(data.counts[-2] == nil)
    }
}

/// The four figures are derived in one pass rather than as four separately
/// computed properties, so these pin the arithmetic that pass has to preserve.
/// A fixed clock: the month and week figures are relative to the current date.
@Suite("HeatmapSummary")
struct HeatmapSummaryTests {

    /// Fixed UTC calendar, so the extracted day/weekday don't shift with the
    /// machine's timezone.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Wednesday, 2026-08-12 — mid-week and mid-month, so neither the week nor
    /// the month window is degenerate. Built with the same calendar that reads
    /// it back.
    private var wednesday: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 12
        components.hour = 12
        return calendar.date(from: components)!
    }

    @Test("the fixture date really is a Wednesday, 2 days from Monday")
    func fixtureIsWednesday() {
        // Apple weekday: Sunday == 1, so Wednesday == 4.
        #expect(calendar.component(.weekday, from: wednesday) == 4)
        #expect(calendar.component(.day, from: wednesday) == 12)
    }

    @Test("sums only the days inside the selected range")
    func totalRespectsSelectedDays() {
        // -100 sits outside a 90-day window and must not be counted.
        let summary = HeatmapSummary(
            counts: [0: 1, -10: 2, -100: 99],
            selectedDays: 90,
            now: wednesday,
            calendar: calendar
        )
        #expect(summary.total == 3)
    }

    @Test("future days are excluded")
    func futureDaysExcluded() {
        let summary = HeatmapSummary(
            counts: [1: 50, 0: 7],
            selectedDays: 90,
            now: wednesday,
            calendar: calendar
        )
        #expect(summary.total == 7)
        #expect(summary.today == 7)
    }

    @Test("month window covers the elapsed days of the current month")
    func monthWindow() {
        // The 12th: offsets 0...-11 are this month, -12 is last month.
        let summary = HeatmapSummary(
            counts: [0: 1, -11: 1, -12: 1],
            selectedDays: 365,
            now: wednesday,
            calendar: calendar
        )
        #expect(summary.thisMonth == 2)
        #expect(summary.total == 3)
    }

    @Test("week window runs back to Monday")
    func weekWindow() {
        // Wednesday is 2 days from Monday: offsets 0, -1, -2 are this week.
        let summary = HeatmapSummary(
            counts: [0: 1, -1: 1, -2: 1, -3: 1],
            selectedDays: 365,
            now: wednesday,
            calendar: calendar
        )
        #expect(summary.thisWeek == 3)
    }

    @Test("empty counts produce all zeroes")
    func emptyCounts() {
        let summary = HeatmapSummary(
            counts: [:],
            selectedDays: 180,
            now: wednesday,
            calendar: calendar
        )
        #expect(summary == HeatmapSummary(
            counts: [:], selectedDays: 180, now: wednesday, calendar: calendar
        ))
        #expect(summary.total == 0)
        #expect(summary.thisMonth == 0)
        #expect(summary.thisWeek == 0)
        #expect(summary.today == 0)
    }
}

@Suite("HeatmapColorRamp")
struct HeatmapColorRampTests {

    @Test("legendColors returns exactly 5 entries")
    func legendColorCount() {
        #expect(HeatmapColorRamp.legendColors(palette: .vividLight).count == 5)
    }

    @Test("same inputs produce same color — deterministic")
    func deterministic() {
        let c1 = HeatmapColorRamp.color(count: 10, maxCount: 20, palette: .vividLight)
        let c2 = HeatmapColorRamp.color(count: 10, maxCount: 20, palette: .vividLight)
        #expect(c1 == c2)
    }

    @Test("count 0 returns separator color")
    func zeroCountReturnsSeparator() {
        let empty = HeatmapColorRamp.color(count: 0, maxCount: 20, palette: .vividLight)
        let separator = Palette.vividLight.separator
        #expect(empty == separator)
    }

    @Test("negative maxCount falls back to 1 — no crash")
    func negativeMaxCountNoCrash() {
        // Should not crash; behaviour defined by max(maxCount, 1) inside helper.
        let c = HeatmapColorRamp.color(count: 5, maxCount: -1, palette: .mutedDark)
        let reference = HeatmapColorRamp.color(count: 5, maxCount: 1, palette: .mutedDark)
        #expect(c == reference)
    }
}
