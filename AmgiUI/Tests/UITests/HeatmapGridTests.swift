//
//  HeatmapGridTests.swift
//  UITests
//
//  Created by Vladimir Gusev on 08.08.2026.
//

import Foundation
import Testing
@testable import UI

@Suite("HeatmapGrid")
struct HeatmapGridTests {

    /// The grid derives each cell's day offset by integer arithmetic instead of
    /// a per-cell `Calendar` diff. This is the check that the shortcut agrees
    /// with the calendar it replaced.
    @Test("cell offsets match a per-cell calendar diff")
    func offsetsMatchCalendarDiff() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let grid = HeatmapGrid.build(weekCount: 26, counts: [:], today: today)

        for week in grid.weeks {
            for day in week.days {
                let expected = cal.dateComponents(
                    [.day],
                    from: today,
                    to: cal.startOfDay(for: day.date)
                ).day
                #expect(day.offset == expected)
            }
        }
    }

    @Test("every week has seven days and days run consecutively")
    func weeksAreConsecutive() {
        let grid = HeatmapGrid.build(weekCount: 26, counts: [:], today: Date())
        let offsets = grid.weeks.flatMap(\.days).map(\.offset)
        let allWeeksFull = grid.weeks.allSatisfy { $0.days.count == 7 }

        #expect(!grid.weeks.isEmpty)
        #expect(allWeeksFull)
        #expect(offsets == Array(offsets.first!...offsets.last!))
    }

    @Test("today is present, is not future, and later days are")
    func todayIsNotFuture() throws {
        let grid = HeatmapGrid.build(weekCount: 26, counts: [:], today: Date())
        let days = grid.weeks.flatMap(\.days)

        let today = try #require(days.first { $0.offset == 0 })
        let laterDaysAreFuture = days.filter { $0.offset > 0 }.allSatisfy(\.isFuture)
        // The grid never extends past the current week.
        let staysWithinCurrentWeek = days.allSatisfy { $0.offset < 7 }

        #expect(!today.isFuture)
        #expect(laterDaysAreFuture)
        #expect(staysWithinCurrentWeek)
    }

    @Test("counts are attached to the matching day offset")
    func countsMapToOffsets() {
        let grid = HeatmapGrid.build(weekCount: 26, counts: [0: 7, -3: 42], today: Date())
        let byOffset = Dictionary(
            uniqueKeysWithValues: grid.weeks.flatMap(\.days).map { ($0.offset, $0.count) }
        )

        #expect(byOffset[0] == 7)
        #expect(byOffset[-3] == 42)
        #expect(byOffset[-4] == 0)
    }

    @Test("covers a full year of past days whatever weekday today is",
          arguments: 0..<7)
    func coverageIsWeekdayIndependent(dayShift: Int) throws {
        let cal = Calendar.current
        // 2026-03-01 is a Sunday, so shifting 0...6 walks every weekday.
        let base = try #require(cal.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let today = try #require(cal.date(byAdding: .day, value: dayShift, to: base))

        let grid = HeatmapGrid.build(weekCount: 53, counts: [:], today: today)
        let earliest = try #require(grid.weeks.flatMap(\.days).map(\.offset).min())

        #expect(grid.weeks.count >= 53)
        // -364...0 inclusive is 365 days counting today: a full year.
        // The week-start snap adds 0-6 more depending on the weekday, so this
        // is the worst case and the only weekday-independent bound.
        #expect(earliest <= -364)
    }

    @Test("week ids are unique and stable across ranges")
    func weekIdentityIsStable() {
        let today = Date()
        let short = HeatmapGrid.build(weekCount: 26, counts: [:], today: today)
        let long = HeatmapGrid.build(weekCount: 53, counts: [:], today: today)

        #expect(Set(long.weeks.map(\.id)).count == long.weeks.count)
        // The same calendar week keeps its identity when the range grows —
        // this is what stops every cell churning on a range change.
        #expect(short.weeks.suffix(5).map(\.id) == long.weeks.suffix(5).map(\.id))
    }

    @Test("month labels mark exactly the columns where the month changes")
    func monthLabelsMarkMonthBoundaries() {
        let cal = Calendar.current
        let grid = HeatmapGrid.build(weekCount: 26, counts: [:], today: Date())

        var lastMonth = -1
        for week in grid.weeks {
            let month = cal.component(.month, from: week.days[0].date)
            #expect((week.monthLabel != nil) == (month != lastMonth))
            lastMonth = month
        }
    }

    @Test("non-positive week counts produce an empty grid rather than crashing")
    func nonPositiveWeekCount() {
        #expect(HeatmapGrid.build(weekCount: 0, counts: [:], today: Date()).weeks.isEmpty)
        #expect(HeatmapGrid.build(weekCount: -4, counts: [:], today: Date()).weeks.isEmpty)
    }
}

@Suite("HeatmapGridCache")
@MainActor
struct HeatmapGridCacheTests {

    @Test("repeated reads with the same inputs return an identical grid")
    func memoizesOnIdenticalInputs() {
        let cache = HeatmapGridCache()
        let today = Date()

        let first = cache.grid(weekCount: 26, counts: [-1: 3], today: today)
        let second = cache.grid(weekCount: 26, counts: [-1: 3], today: today)

        #expect(first == second)
    }

    @Test("rebuilds when the range or the counts change")
    func rebuildsOnInputChange() {
        let cache = HeatmapGridCache()
        let today = Date()

        let base = cache.grid(weekCount: 26, counts: [-1: 3], today: today)
        let wider = cache.grid(weekCount: 53, counts: [-1: 3], today: today)
        #expect(wider.weeks.count > base.weeks.count)

        let recounted = cache.grid(weekCount: 53, counts: [-1: 99], today: today)
        let day = recounted.weeks.flatMap(\.days).first { $0.offset == -1 }
        #expect(day?.count == 99)
    }
}
