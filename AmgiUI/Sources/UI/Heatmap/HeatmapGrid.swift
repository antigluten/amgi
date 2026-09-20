//
//  HeatmapGrid.swift
//  UI
//
//  Created by Vladimir Gusev on 08.08.2026.
//

public import Foundation

/// One day cell in a heatmap grid, with everything the cell view needs already
/// resolved. Cells carry no `Calendar` work of their own — building the grid
/// does that once for the whole range.
public struct HeatmapDay: Identifiable, Equatable, Sendable {
    /// Day offset from today: `0` is today, negative is the past.
    public let offset: Int
    public let date: Date
    public let count: Int

    public var id: Int { offset }
    public var isFuture: Bool { offset > 0 }

    public init(offset: Int, date: Date, count: Int) {
        self.offset = offset
        self.date = date
        self.count = count
    }
}

/// One week column: seven days plus the month label to draw above it, if this
/// is the column where a new month starts.
public struct HeatmapWeek: Identifiable, Equatable, Sendable {
    public let days: [HeatmapDay]
    public let monthLabel: String?

    /// Stable across range changes — the first day's offset, not a row index.
    public var id: Int { days.first?.offset ?? 0 }

    public init(days: [HeatmapDay], monthLabel: String?) {
        self.days = days
        self.monthLabel = monthLabel
    }
}

/// A precomputed week-by-week heatmap grid.
///
/// The whole point of this type is that `body` never does calendar arithmetic.
/// Building walks the range once; every cell's day offset is plain integer
/// arithmetic off the grid's start, because consecutive calendar days always
/// differ by exactly one day.
public struct HeatmapGrid: Equatable, Sendable {
    public let weeks: [HeatmapWeek]

    public static let empty = HeatmapGrid(weeks: [])

    public init(weeks: [HeatmapWeek]) {
        self.weeks = weeks
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    /// Builds `weekCount` week-columns ending with the week containing `today`.
    public static func build(
        weekCount: Int,
        counts: [Int: Int],
        today now: Date = Date()
    ) -> HeatmapGrid {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard weekCount > 0,
              let startDate = cal.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: today),
              let startOfWeek = cal.date(
                  from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
              ),
              let startOffset = cal.dateComponents([.day], from: today, to: startOfWeek).day
        else { return .empty }

        var weeks: [HeatmapWeek] = []
        weeks.reserveCapacity(max(-startOffset / 7 + 1, 0))
        var lastMonth = -1
        var cursor = startOfWeek
        var dayIndex = 0

        while cursor <= today {
            var days: [HeatmapDay] = []
            days.reserveCapacity(7)
            for weekday in 0..<7 {
                let step = dayIndex + weekday
                guard let date = cal.date(byAdding: .day, value: step, to: startOfWeek) else { continue }
                let offset = startOffset + step
                days.append(HeatmapDay(offset: offset, date: date, count: counts[offset] ?? 0))
            }
            guard let first = days.first else { break }

            let month = cal.component(.month, from: first.date)
            let label = month == lastMonth ? nil : monthFormatter.string(from: first.date)
            lastMonth = month
            weeks.append(HeatmapWeek(days: days, monthLabel: label))

            dayIndex += 7
            guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }

        return HeatmapGrid(weeks: weeks)
    }
}

/// Memoizes the built grid across `body` evaluations.
///
/// Deliberately *not* `@Observable`: it's a pure cache, so a view reading it
/// never registers a dependency and refilling it never invalidates anything.
/// Held in `@State` so it survives view-struct recreation.
@MainActor
public final class HeatmapGridCache {
    private struct Key: Equatable {
        let weekCount: Int
        let counts: [Int: Int]
        let startOfToday: Date
    }

    private var key: Key?
    private var cached: HeatmapGrid = .empty

    public init() {}

    /// Returns the cached grid, rebuilding only when the range, the counts, or
    /// the current day actually changed.
    public func grid(weekCount: Int, counts: [Int: Int], today: Date = Date()) -> HeatmapGrid {
        let startOfToday = Calendar.current.startOfDay(for: today)
        let next = Key(weekCount: weekCount, counts: counts, startOfToday: startOfToday)
        guard next != key else { return cached }
        cached = HeatmapGrid.build(weekCount: weekCount, counts: counts, today: startOfToday)
        key = next
        return cached
    }
}
