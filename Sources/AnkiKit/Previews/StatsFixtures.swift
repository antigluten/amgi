#if DEBUG && canImport(SwiftUI)
import Foundation

// Sample stats data for the Stats chart `#Preview` blocks. Deterministic
// (no RNG) so preview snapshots stay stable, and gated by DEBUG +
// canImport(SwiftUI) like DomainFixtures.swift so release/CLI builds skip them.

extension FutureDueSeries {
    /// Tapering near-term load over the next month. Day 1 carries the
    /// "due tomorrow" figure the chart calls out.
    public static let sample: FutureDueSeries = {
        var due: [Int: Int] = [:]
        for day in 0...30 {
            due[day] = max(2, 44 - day + (day * 7) % 9)
        }
        return FutureDueSeries(futureDue: due, haveBacklog: true, dailyLoad: 34)
    }()
}

extension AddedSeries {
    /// ~2 months of cards added per day (negative offsets are past days).
    public static let sample: AddedSeries = {
        var added: [Int: Int] = [:]
        for offset in (-60...0) {
            let i = -offset
            added[offset] = max(0, 14 + (i * 5) % 17 - 5)
        }
        return AddedSeries(added: added)
    }()
}

extension IntervalsBuckets {
    /// One key per interval bucket the chart groups into, so every bar shows.
    public static let sample = IntervalsBuckets(intervals: [
        1: 60, 2: 48, 5: 92, 10: 130, 21: 88,
        45: 140, 75: 96, 150: 120, 240: 64, 400: 30,
    ])
}

extension EaseBuckets {
    /// Ease factors in per-mille (2500 == 250%), matching the proto units the
    /// chart divides by 10 for its average label.
    public static let sample = EaseBuckets(
        eases: [
            1300: 8, 1500: 22, 1700: 40, 1900: 72, 2100: 96, 2300: 140,
            2500: 168, 2700: 120, 2900: 84, 3100: 50, 3300: 26, 3500: 11,
        ],
        average: 2500
    )
}

extension RetrievabilityBuckets {
    /// Card counts per 5% retrievability bucket, skewed toward high recall.
    public static let sample: RetrievabilityBuckets = {
        var buckets: [Int: Int] = [:]
        for pct in stride(from: 0, through: 100, by: 5) {
            buckets[pct] = max(0, (pct - 25) / 2 + (pct % 7))
        }
        return RetrievabilityBuckets(retrievability: buckets, average: 88, sumByCard: 1240, sumByNote: 1180)
    }()
}

extension TodayCounts {
    public static let sample = TodayCounts(
        answerCount: 187,
        answerMillis: 742_000,
        correctCount: 161,
        matureCorrect: 92,
        matureCount: 104,
        learnCount: 38,
        reviewCount: 121,
        relearnCount: 9,
        earlyReviewCount: 4
    )
}

extension HoursBuckets {
    /// A daytime-skewed 24-hour profile, reused across all periods.
    public static let sample: HoursBuckets = {
        let hours: [Hour] = (0..<24).map { h in
            let total = (7...23).contains(h) ? 18 + (h * 5) % 22 : 2
            return Hour(total: total, correct: Int(Double(total) * 0.82))
        }
        return HoursBuckets(oneMonth: hours, threeMonths: hours, oneYear: hours, allTime: hours)
    }()
}

extension ButtonsBuckets {
    /// Again/Hard/Good/Easy tallies per card state, reused across all periods.
    public static let sample: ButtonsBuckets = {
        let counts = ButtonCounts(
            learning: [40, 90, 320, 60],
            young: [55, 120, 410, 95],
            mature: [30, 80, 520, 140]
        )
        return ButtonsBuckets(oneMonth: counts, threeMonths: counts, oneYear: counts, allTime: counts)
    }()
}

extension CardCountsSeries {
    public static let sample: CardCountsSeries = {
        let counts = Counts(
            newCards: 120,
            learn: 34,
            relearn: 12,
            young: 410,
            mature: 880,
            suspended: 24,
            buried: 8
        )
        return CardCountsSeries(includingInactive: counts, excludingInactive: counts)
    }()
}

extension TrueRetentionStats {
    public static let sample: TrueRetentionStats = {
        func r(_ yp: Int, _ yf: Int, _ mp: Int, _ mf: Int) -> TrueRetention {
            TrueRetention(youngPassed: yp, youngFailed: yf, maturePassed: mp, matureFailed: mf)
        }
        return TrueRetentionStats(
            today: r(40, 6, 70, 5),
            yesterday: r(38, 8, 66, 7),
            week: r(240, 44, 470, 38),
            month: r(980, 180, 1900, 150),
            year: r(11_000, 2_100, 22_000, 1_700),
            allTime: r(31_000, 6_200, 60_000, 4_900)
        )
    }()
}

extension GraphsSnapshot {
    /// A fully-populated snapshot wiring every sub-fixture together — used by
    /// `StatsClient.previewValue` and any whole-dashboard preview.
    public static let sample = GraphsSnapshot(
        buttons: .sample,
        cardCounts: .sample,
        hours: .sample,
        today: .sample,
        eases: .sample,
        intervals: .sample,
        futureDue: .sample,
        added: .sample,
        reviews: .sampleYear,
        retrievability: .sample,
        fsrs: true,
        trueRetention: .sample
    )
}
#endif
