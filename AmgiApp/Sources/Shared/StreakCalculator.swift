import AnkiKit

/// Consecutive-day review-streak math. Pulled from `WriteWidgetSnapshot`
/// so the widget writer and the Library hero card share one rule.
///
/// `reviews` is the same `[Int: ReviewCountsAndTimes.Reviews]` shape
/// returned by `StatsClient.fetchGraphs(...).reviews.count` — key 0
/// is today, -1 is yesterday, etc.
enum StreakCalculator {
    /// Count of consecutive days backward from today (or yesterday, if
    /// today is empty) where at least one review was answered.
    static func streak(reviews: [Int: ReviewCountsAndTimes.Reviews], window: Int = 28) -> Int {
        let todayTotal = reviews[0].map(dayTotal) ?? 0
        let startOffset = todayTotal > 0 ? 0 : -1
        var streak = 0
        for offset in stride(from: startOffset, through: -(window - 1), by: -1) {
            guard let r = reviews[offset], dayTotal(r) > 0 else { break }
            streak += 1
        }
        return streak
    }

    /// Per-day totals for the last `days` calendar days, oldest first.
    /// Missing offsets render as 0.
    static func lastNDaysTotals(reviews: [Int: ReviewCountsAndTimes.Reviews], days: Int) -> [Int] {
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
