import Foundation
import AnkiKit
import AmgiUI

/// Projects a `GraphsSnapshot` (scoped to a single deck via
/// `search: "deck:\"<name>\""`) into the value types the AmgiUI screen
/// consumes. Lives in the Container layer so AmgiUI never has to know
/// about GraphsSnapshot / AnkiProto.
enum DeckDetailStats {
    struct Snapshot: Equatable {
        let insights: InsightsCardData
        let subtitle: String
    }

    static func project(graphs: GraphsSnapshot, isEmpty: Bool) -> Snapshot {
        Snapshot(
            insights: buildInsights(graphs: graphs),
            subtitle: buildSubtitle(graphs: graphs, isEmpty: isEmpty)
        )
    }

    // MARK: - Insights

    static func buildInsights(graphs: GraphsSnapshot) -> InsightsCardData {
        let month = graphs.trueRetention.month
        let passed = month.youngPassed + month.maturePassed
        let failed = month.youngFailed + month.matureFailed
        let total = passed + failed
        let retention: Int? = total > 0 ? Int((Double(passed) / Double(total) * 100).rounded()) : nil

        // Avg cards/day over the last 30 days (offsets -29 ... 0).
        var totalReviews = 0
        for offset in -29 ... 0 {
            guard let day = graphs.reviews.count[offset] else { continue }
            totalReviews += day.learn + day.relearn + day.young + day.mature + day.filtered
        }
        let avg: Int? = totalReviews > 0 ? Int((Double(totalReviews) / 30.0).rounded()) : nil

        // Mature card count — use excludingInactive when populated, fall back
        // to includingInactive. TODO: graph protobuf scoping by deck search
        // is not fully reliable for cardCounts upstream today — this can
        // surface a collection-wide mature count. Acceptable for v1; reroute
        // through SearchCards as the follow-up if it bites.
        let excl = graphs.cardCounts.excludingInactive
        let incl = graphs.cardCounts.includingInactive
        let mature = excl.mature > 0 ? excl.mature : incl.mature

        return InsightsCardData(
            retention30dPercent: retention,
            avgCardsPerDay: avg,
            matureCards: mature
        )
    }

    // MARK: - Subtitle

    static func buildSubtitle(graphs: GraphsSnapshot, isEmpty: Bool) -> String {
        if isEmpty {
            return "No cards yet · Add some to start studying"
        }

        func dayTotal(_ rev: ReviewCountsAndTimes.Reviews) -> Int {
            rev.learn + rev.relearn + rev.young + rev.mature + rev.filtered
        }
        let todayTotal = graphs.reviews.count[0].map(dayTotal) ?? 0
        let startOffset = todayTotal > 0 ? 0 : -1

        // Streak — consecutive review-days backwards from today (or yesterday).
        var streak = 0
        for offset in stride(from: startOffset, through: -59, by: -1) {
            guard let rev = graphs.reviews.count[offset] else { break }
            guard dayTotal(rev) > 0 else { break }
            streak += 1
        }

        // Last-studied — most recent day-offset with reviews.
        var lastOffset: Int? = nil
        for offset in stride(from: 0, through: -59, by: -1) {
            if let rev = graphs.reviews.count[offset], dayTotal(rev) > 0 {
                lastOffset = offset
                break
            }
        }

        let lastStudied: String
        switch lastOffset {
        case nil: lastStudied = "never"
        case .some(0): lastStudied = "today"
        case .some(-1): lastStudied = "yesterday"
        case .some(let off):
            let date = Calendar.current.date(byAdding: .day, value: off, to: Date()) ?? Date()
            lastStudied = date.formatted(.dateTime.month(.abbreviated).day())
        }

        if streak > 0 {
            return "Last studied \(lastStudied) · \(streak)-day streak"
        } else if lastOffset != nil {
            return "Last studied \(lastStudied)"
        } else {
            return "No reviews yet"
        }
    }
}
