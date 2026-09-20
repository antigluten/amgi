//
//  StreakCalculator.swift
//  AppCore
//
//  Created by Vladimir Gusev on 14.05.2026.
//

public import AnkiKit

/// Consecutive-day review-streak math. Pulled from `WriteWidgetSnapshot`
/// so the widget writer and the Library hero card share one rule.
///
/// `reviews` is the same `[Int: ReviewCountsAndTimes.Reviews]` shape
/// returned by `StatsClient.fetchGraphs(...).reviews.count` — key 0
/// is today, -1 is yesterday, etc.
public enum StreakCalculator {
    /// Count of consecutive days backward from today (or yesterday, if
    /// today is empty) where at least one review was answered.
    public static func streak(reviews: [Int: ReviewCountsAndTimes.Reviews], window: Int = 28) -> Int {
        // Delegates to AnkiKit.DayStreak so the Stats heatmap — which lives
        // in StatsCharts and can't see this module — runs the same algorithm
        // rather than its own.
        DayStreak.count(totals: reviews.mapValues(dayTotal), window: window)
    }

    public static func activeDays(
        reviews: [Int: ReviewCountsAndTimes.Reviews],
        in offsets: ClosedRange<Int>
    ) -> Int {
        offsets.count { offset in
            (reviews[offset].map(dayTotal) ?? 0) > 0
        }
    }

    /// Per-day totals for the last `days` calendar days, oldest first.
    /// Missing offsets render as 0.
    public static func lastNDaysTotals(reviews: [Int: ReviewCountsAndTimes.Reviews], days: Int) -> [Int] {
        (-(days - 1)...0).map { offset in
            reviews[offset].map(dayTotal) ?? 0
        }
    }

}

private extension StreakCalculator {
    static func dayTotal(_ r: ReviewCountsAndTimes.Reviews) -> Int {
        r.learn + r.relearn + r.young + r.mature + r.filtered
    }
}
