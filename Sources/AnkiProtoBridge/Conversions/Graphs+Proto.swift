package import AnkiKit
package import AnkiProto

// MARK: - Simple bucketed series

package extension AddedSeries {
    init(_ proto: Anki_Stats_GraphsResponse.Added) {
        self.init(
            added: Dictionary(uniqueKeysWithValues: proto.added.map { (Int($0.key), Int($0.value)) })
        )
    }
}

package extension IntervalsBuckets {
    init(_ proto: Anki_Stats_GraphsResponse.Intervals) {
        self.init(
            intervals: Dictionary(uniqueKeysWithValues: proto.intervals.map { (Int($0.key), Int($0.value)) })
        )
    }
}

package extension EaseBuckets {
    init(_ proto: Anki_Stats_GraphsResponse.Eases) {
        self.init(
            eases: Dictionary(uniqueKeysWithValues: proto.eases.map { (Int($0.key), Int($0.value)) }),
            average: proto.average
        )
    }
}

package extension RetrievabilityBuckets {
    init(_ proto: Anki_Stats_GraphsResponse.Retrievability) {
        self.init(
            retrievability: Dictionary(uniqueKeysWithValues: proto.retrievability.map { (Int($0.key), Int($0.value)) }),
            average: proto.average,
            sumByCard: proto.sumByCard,
            sumByNote: proto.sumByNote
        )
    }
}

package extension FutureDueSeries {
    init(_ proto: Anki_Stats_GraphsResponse.FutureDue) {
        self.init(
            futureDue: Dictionary(uniqueKeysWithValues: proto.futureDue.map { (Int($0.key), Int($0.value)) }),
            haveBacklog: proto.haveBacklog,
            dailyLoad: Int(proto.dailyLoad)
        )
    }
}

// MARK: - Today

package extension TodayCounts {
    init(_ proto: Anki_Stats_GraphsResponse.Today) {
        self.init(
            answerCount: Int(proto.answerCount),
            answerMillis: Int(proto.answerMillis),
            correctCount: Int(proto.correctCount),
            matureCorrect: Int(proto.matureCorrect),
            matureCount: Int(proto.matureCount),
            learnCount: Int(proto.learnCount),
            reviewCount: Int(proto.reviewCount),
            relearnCount: Int(proto.relearnCount),
            earlyReviewCount: Int(proto.earlyReviewCount)
        )
    }
}

// MARK: - Hours

package extension HoursBuckets.Hour {
    init(_ proto: Anki_Stats_GraphsResponse.Hours.Hour) {
        self.init(total: Int(proto.total), correct: Int(proto.correct))
    }
}

package extension HoursBuckets {
    init(_ proto: Anki_Stats_GraphsResponse.Hours) {
        self.init(
            oneMonth: proto.oneMonth.map(Hour.init),
            threeMonths: proto.threeMonths.map(Hour.init),
            oneYear: proto.oneYear.map(Hour.init),
            allTime: proto.allTime.map(Hour.init)
        )
    }
}

// MARK: - Reviews

package extension ReviewCountsAndTimes.Reviews {
    init(_ proto: Anki_Stats_GraphsResponse.ReviewCountsAndTimes.Reviews) {
        self.init(
            learn: Int(proto.learn),
            relearn: Int(proto.relearn),
            young: Int(proto.young),
            mature: Int(proto.mature),
            filtered: Int(proto.filtered)
        )
    }
}

package extension ReviewCountsAndTimes {
    init(_ proto: Anki_Stats_GraphsResponse.ReviewCountsAndTimes) {
        self.init(
            count: Dictionary(uniqueKeysWithValues: proto.count.map { (Int($0.key), Reviews($0.value)) }),
            time: Dictionary(uniqueKeysWithValues: proto.time.map { (Int($0.key), Reviews($0.value)) })
        )
    }
}

// MARK: - Buttons

package extension ButtonsBuckets.ButtonCounts {
    init(_ proto: Anki_Stats_GraphsResponse.Buttons.ButtonCounts) {
        self.init(
            learning: proto.learning.map(Int.init),
            young: proto.young.map(Int.init),
            mature: proto.mature.map(Int.init)
        )
    }
}

package extension ButtonsBuckets {
    init(_ proto: Anki_Stats_GraphsResponse.Buttons) {
        self.init(
            oneMonth: ButtonCounts(proto.oneMonth),
            threeMonths: ButtonCounts(proto.threeMonths),
            oneYear: ButtonCounts(proto.oneYear),
            allTime: ButtonCounts(proto.allTime)
        )
    }
}

// MARK: - CardCounts

package extension CardCountsSeries.Counts {
    init(_ proto: Anki_Stats_GraphsResponse.CardCounts.Counts) {
        self.init(
            newCards: Int(proto.newCards),
            learn: Int(proto.learn),
            relearn: Int(proto.relearn),
            young: Int(proto.young),
            mature: Int(proto.mature),
            suspended: Int(proto.suspended),
            buried: Int(proto.buried)
        )
    }
}

package extension CardCountsSeries {
    init(_ proto: Anki_Stats_GraphsResponse.CardCounts) {
        self.init(
            includingInactive: Counts(proto.includingInactive),
            excludingInactive: Counts(proto.excludingInactive)
        )
    }
}

// MARK: - TrueRetention

package extension TrueRetentionStats.TrueRetention {
    init(_ proto: Anki_Stats_GraphsResponse.TrueRetentionStats.TrueRetention) {
        self.init(
            youngPassed: Int(proto.youngPassed),
            youngFailed: Int(proto.youngFailed),
            maturePassed: Int(proto.maturePassed),
            matureFailed: Int(proto.matureFailed)
        )
    }
}

package extension TrueRetentionStats {
    init(_ proto: Anki_Stats_GraphsResponse.TrueRetentionStats) {
        self.init(
            today: TrueRetention(proto.today),
            yesterday: TrueRetention(proto.yesterday),
            week: TrueRetention(proto.week),
            month: TrueRetention(proto.month),
            year: TrueRetention(proto.year),
            allTime: TrueRetention(proto.allTime)
        )
    }
}

// MARK: - GraphsSnapshot

package extension GraphsSnapshot {
    init(_ proto: Anki_Stats_GraphsResponse) {
        self.init(
            buttons: ButtonsBuckets(proto.buttons),
            cardCounts: CardCountsSeries(proto.cardCounts),
            hours: HoursBuckets(proto.hours),
            today: TodayCounts(proto.today),
            eases: EaseBuckets(proto.eases),
            difficulty: EaseBuckets(proto.difficulty),
            intervals: IntervalsBuckets(proto.intervals),
            futureDue: FutureDueSeries(proto.futureDue),
            added: AddedSeries(proto.added),
            reviews: ReviewCountsAndTimes(proto.reviews),
            rolloverHour: Int(proto.rolloverHour),
            retrievability: RetrievabilityBuckets(proto.retrievability),
            fsrs: proto.fsrs,
            stability: IntervalsBuckets(proto.stability),
            trueRetention: TrueRetentionStats(proto.trueRetention)
        )
    }
}

extension GraphsSnapshot: BridgeDecodable {
    package typealias Proto = Anki_Stats_GraphsResponse
}
