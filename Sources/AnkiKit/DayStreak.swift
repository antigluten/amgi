//
//  DayStreak.swift
//  AnkiKit
//
//  Created by Vladimir Gusev on 20.08.2026.
//

/// Consecutive-day review-streak counting.
///
/// One algorithm, in the lowest module every caller can see. It previously
/// existed three times — `AppCore.StreakCalculator`, the widget's use of
/// it, and `StatsCharts.HeatmapChartOptimized.currentStreak` — with different
/// edge-case handling, so the same user could see different streak numbers on
/// the Library card and the Stats dashboard.
///
/// Keys are day offsets: `0` is today, `-1` yesterday, and so on.
public enum DayStreak: Sendable {
    /// Consecutive days with at least one review, counting backward from
    /// today — or from yesterday when today has none, so an unstarted day
    /// doesn't read as a broken streak.
    ///
    /// - Parameter window: how many days back to consider. Pass the range the
    ///   caller actually loaded; a window shorter than the data silently caps
    ///   the result.
    public static func count(totals: [Int: Int], window: Int) -> Int {
        guard window > 0 else { return 0 }
        let startOffset = (totals[0] ?? 0) > 0 ? 0 : -1
        var streak = 0
        for offset in stride(from: startOffset, through: -(window - 1), by: -1) {
            guard let total = totals[offset], total > 0 else { break }
            streak += 1
        }
        return streak
    }
}
