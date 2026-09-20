//
//  StreakSummary.swift
//  StatsFeature
//
//  Created by Vladimir Gusev on 18.09.2026.
//

import AppCore
import AnkiKit

struct StreakSummary: Equatable {
    static let window = 365

    let days: Int
    let comparison: Int

    init(days: Int, comparison: Int) {
        self.days = days
        self.comparison = comparison
    }

    init(reviews: [Int: ReviewCountsAndTimes.Reviews]) {
        days = StreakCalculator.streak(reviews: reviews, window: Self.window)
        comparison = StreakCalculator.activeDays(reviews: reviews, in: -29...0)
            - StreakCalculator.activeDays(reviews: reviews, in: -59...(-30))
    }
}
