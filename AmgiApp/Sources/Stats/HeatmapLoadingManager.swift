import Foundation
import os
import SwiftUI
import AnkiProto

/// Manages incremental loading of heatmap data with configurable date range
public actor HeatmapLoadingManager: Sendable {
    // MARK: - Configuration

    /// Default number of days to load initially
    public static let defaultInitialDays = 180  // 6 months

    /// Number of days to load when expanding
    public static let expandLoadDays = 90      // 3 months at a time

    // MARK: - State

    private var allData: [Int: ReviewCount] = [:]
    private var currentVisibleDays: Int
    private var isExpanding = false

    public init(defaultVisibleDays: Int = HeatmapLoadingManager.defaultInitialDays) {
        self.currentVisibleDays = defaultVisibleDays
    }

    // MARK: - Public API

    /// Load or reload all data from response
    public func loadAllData(_ reviews: Anki_Stats_GraphsResponse.ReviewCountsAndTimes) {
        var data: [Int: ReviewCount] = [:]
        for (dayOffset, rev) in reviews.count {
            let total = Int(rev.learn + rev.relearn + rev.young + rev.mature + rev.filtered)
            if total > 0 {
                data[Int(dayOffset)] = ReviewCount(
                    learn: Int(rev.learn),
                    relearn: Int(rev.relearn),
                    young: Int(rev.young),
                    mature: Int(rev.mature),
                    filtered: Int(rev.filtered),
                    total: total
                )
            }
        }
        self.allData = data
        logger.info("Loaded heatmap data: \(data.count) days with reviews")
    }

    /// Get currently visible data (filtered by date range)
    public func getVisibleData() -> [Int: ReviewCount] {
        filterDataByDateRange()
    }

    /// Expand the visible range by loading more historical data
    public func expandDateRange() {
        guard !isExpanding else { return }
        isExpanding = true
        defer { isExpanding = false }

        currentVisibleDays += Self.expandLoadDays
        logger.info("Expanded heatmap range to \(self.currentVisibleDays) days")
    }

    /// Set new date range
    public func setDateRange(days: Int) {
        currentVisibleDays = max(1, min(days, 3650))  // 1 day to 10 years
        logger.info("Set heatmap date range to \(days) days")
    }

    /// Get current configuration
    public func getCurrentConfig() -> HeatmapConfig {
        HeatmapConfig(visibleDays: currentVisibleDays, totalDataPoints: allData.count)
    }

    /// Get statistics for current visible range
    public func getVisibleStats() -> HeatmapStats {
        let visibleData = getVisibleData()
        let total = visibleData.values.reduce(0) { $0 + $1.total }
        let maxCount = visibleData.values.map { $0.total }.max() ?? 1
        return HeatmapStats(
            totalReviews: total,
            maxReviewsInDay: maxCount,
            visibleDayCount: visibleData.count,
            dateRange: currentVisibleDays
        )
    }

    // MARK: - Private Helpers

    private func filterDataByDateRange() -> [Int: ReviewCount] {
        allData.filter { dayOffset, _ in
            dayOffset >= -currentVisibleDays && dayOffset <= 0
        }
    }
}

// MARK: - Data Structures

public struct ReviewCount: Sendable {
    public let learn: Int
    public let relearn: Int
    public let young: Int
    public let mature: Int
    public let filtered: Int
    public let total: Int
}

public struct HeatmapConfig: Sendable {
    public let visibleDays: Int
    public let totalDataPoints: Int
}

public struct HeatmapStats: Sendable {
    public let totalReviews: Int
    public let maxReviewsInDay: Int
    public let visibleDayCount: Int
    public let dateRange: Int
}

// MARK: - Logging

private let logger = Logger(subsystem: "com.amgiapp", category: "heatmap")
