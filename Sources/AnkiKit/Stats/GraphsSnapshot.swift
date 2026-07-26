/// Mirror for `Anki_Stats_GraphsResponse`. The Stats dashboard fetches
/// one of these and threads sub-types into individual chart views.
///
/// Naming convention: each top-level field is non-optional (zero-valued
/// defaults match the proto's "unset means defaults" semantics for
/// charts), and nested Hashable structs preserve enough field detail
/// to round-trip through tests.
public struct GraphsSnapshot: Sendable, Hashable {
    public var buttons: ButtonsBuckets
    public var cardCounts: CardCountsSeries
    public var hours: HoursBuckets
    public var today: TodayCounts
    public var eases: EaseBuckets
    public var difficulty: EaseBuckets
    public var intervals: IntervalsBuckets
    public var futureDue: FutureDueSeries
    public var added: AddedSeries
    public var reviews: ReviewCountsAndTimes
    public var rolloverHour: Int
    public var retrievability: RetrievabilityBuckets
    public var fsrs: Bool
    public var stability: IntervalsBuckets
    public var trueRetention: TrueRetentionStats

    public init(
        buttons: ButtonsBuckets = ButtonsBuckets(),
        cardCounts: CardCountsSeries = CardCountsSeries(),
        hours: HoursBuckets = HoursBuckets(),
        today: TodayCounts = TodayCounts(),
        eases: EaseBuckets = EaseBuckets(),
        difficulty: EaseBuckets = EaseBuckets(),
        intervals: IntervalsBuckets = IntervalsBuckets(),
        futureDue: FutureDueSeries = FutureDueSeries(),
        added: AddedSeries = AddedSeries(),
        reviews: ReviewCountsAndTimes = ReviewCountsAndTimes(),
        rolloverHour: Int = 0,
        retrievability: RetrievabilityBuckets = RetrievabilityBuckets(),
        fsrs: Bool = false,
        stability: IntervalsBuckets = IntervalsBuckets(),
        trueRetention: TrueRetentionStats = TrueRetentionStats()
    ) {
        self.buttons = buttons
        self.cardCounts = cardCounts
        self.hours = hours
        self.today = today
        self.eases = eases
        self.difficulty = difficulty
        self.intervals = intervals
        self.futureDue = futureDue
        self.added = added
        self.reviews = reviews
        self.rolloverHour = rolloverHour
        self.retrievability = retrievability
        self.fsrs = fsrs
        self.stability = stability
        self.trueRetention = trueRetention
    }
}

// MARK: - Simple bucketed series

public struct AddedSeries: Sendable, Hashable {
    /// Day-offset → cards added. Negative offsets are past days.
    public var added: [Int: Int]
    public init(added: [Int: Int] = [:]) { self.added = added }
}

public struct IntervalsBuckets: Sendable, Hashable {
    /// Interval bucket (days) → card count.
    public var intervals: [Int: Int]
    public init(intervals: [Int: Int] = [:]) { self.intervals = intervals }
}

public struct EaseBuckets: Sendable, Hashable {
    /// Ease bucket (proto units) → card count.
    public var eases: [Int: Int]
    public var average: Float
    public init(eases: [Int: Int] = [:], average: Float = 0) {
        self.eases = eases
        self.average = average
    }
}

public struct RetrievabilityBuckets: Sendable, Hashable {
    /// Retrievability bucket → card count.
    public var retrievability: [Int: Int]
    public var average: Float
    public var sumByCard: Float
    public var sumByNote: Float
    public init(
        retrievability: [Int: Int] = [:],
        average: Float = 0,
        sumByCard: Float = 0,
        sumByNote: Float = 0
    ) {
        self.retrievability = retrievability
        self.average = average
        self.sumByCard = sumByCard
        self.sumByNote = sumByNote
    }
}

public struct FutureDueSeries: Sendable, Hashable {
    /// Day-offset → cards due. Negative offsets indicate the backlog.
    public var futureDue: [Int: Int]
    public var haveBacklog: Bool
    public var dailyLoad: Int
    public init(futureDue: [Int: Int] = [:], haveBacklog: Bool = false, dailyLoad: Int = 0) {
        self.futureDue = futureDue
        self.haveBacklog = haveBacklog
        self.dailyLoad = dailyLoad
    }
}

// MARK: - Today

public struct TodayCounts: Sendable, Hashable {
    public var answerCount: Int
    public var answerMillis: Int
    public var correctCount: Int
    public var matureCorrect: Int
    public var matureCount: Int
    public var learnCount: Int
    public var reviewCount: Int
    public var relearnCount: Int
    public var earlyReviewCount: Int

    public init(
        answerCount: Int = 0,
        answerMillis: Int = 0,
        correctCount: Int = 0,
        matureCorrect: Int = 0,
        matureCount: Int = 0,
        learnCount: Int = 0,
        reviewCount: Int = 0,
        relearnCount: Int = 0,
        earlyReviewCount: Int = 0
    ) {
        self.answerCount = answerCount
        self.answerMillis = answerMillis
        self.correctCount = correctCount
        self.matureCorrect = matureCorrect
        self.matureCount = matureCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
        self.relearnCount = relearnCount
        self.earlyReviewCount = earlyReviewCount
    }
}

// MARK: - Hours

/// Per-period hourly buckets. Each `Hour` array contains 24 entries
/// indexed by hour-of-day.
public struct HoursBuckets: Sendable, Hashable {
    public var oneMonth: [Hour]
    public var threeMonths: [Hour]
    public var oneYear: [Hour]
    public var allTime: [Hour]

    public init(
        oneMonth: [Hour] = [],
        threeMonths: [Hour] = [],
        oneYear: [Hour] = [],
        allTime: [Hour] = []
    ) {
        self.oneMonth = oneMonth
        self.threeMonths = threeMonths
        self.oneYear = oneYear
        self.allTime = allTime
    }

    public struct Hour: Sendable, Hashable {
        public var total: Int
        public var correct: Int
        public init(total: Int = 0, correct: Int = 0) {
            self.total = total
            self.correct = correct
        }
    }
}

// MARK: - Reviews

/// Daily review counts and time-spent, grouped by review type.
public struct ReviewCountsAndTimes: Sendable, Hashable {
    /// Day-offset → counts, broken down by card state.
    public var count: [Int: Reviews]
    /// Day-offset → time-spent (millis), broken down by card state.
    public var time: [Int: Reviews]

    public init(count: [Int: Reviews] = [:], time: [Int: Reviews] = [:]) {
        self.count = count
        self.time = time
    }

    public struct Reviews: Sendable, Hashable {
        public var learn: Int
        public var relearn: Int
        public var young: Int
        public var mature: Int
        public var filtered: Int

        public init(
            learn: Int = 0,
            relearn: Int = 0,
            young: Int = 0,
            mature: Int = 0,
            filtered: Int = 0
        ) {
            self.learn = learn
            self.relearn = relearn
            self.young = young
            self.mature = mature
            self.filtered = filtered
        }
    }
}

// MARK: - Buttons

/// Answer-button counts grouped by period and card state.
public struct ButtonsBuckets: Sendable, Hashable {
    public var oneMonth: ButtonCounts
    public var threeMonths: ButtonCounts
    public var oneYear: ButtonCounts
    public var allTime: ButtonCounts

    public init(
        oneMonth: ButtonCounts = ButtonCounts(),
        threeMonths: ButtonCounts = ButtonCounts(),
        oneYear: ButtonCounts = ButtonCounts(),
        allTime: ButtonCounts = ButtonCounts()
    ) {
        self.oneMonth = oneMonth
        self.threeMonths = threeMonths
        self.oneYear = oneYear
        self.allTime = allTime
    }

    /// Each `[Int]` array is 4 entries — one per Anki answer button
    /// (Again, Hard, Good, Easy).
    public struct ButtonCounts: Sendable, Hashable {
        public var learning: [Int]
        public var young: [Int]
        public var mature: [Int]
        public init(learning: [Int] = [], young: [Int] = [], mature: [Int] = []) {
            self.learning = learning
            self.young = young
            self.mature = mature
        }
    }
}

// MARK: - CardCounts

public struct CardCountsSeries: Sendable, Hashable {
    public var includingInactive: Counts
    public var excludingInactive: Counts

    public init(includingInactive: Counts = Counts(), excludingInactive: Counts = Counts()) {
        self.includingInactive = includingInactive
        self.excludingInactive = excludingInactive
    }

    public struct Counts: Sendable, Hashable {
        public var newCards: Int
        public var learn: Int
        public var relearn: Int
        public var young: Int
        public var mature: Int
        public var suspended: Int
        public var buried: Int

        public init(
            newCards: Int = 0,
            learn: Int = 0,
            relearn: Int = 0,
            young: Int = 0,
            mature: Int = 0,
            suspended: Int = 0,
            buried: Int = 0
        ) {
            self.newCards = newCards
            self.learn = learn
            self.relearn = relearn
            self.young = young
            self.mature = mature
            self.suspended = suspended
            self.buried = buried
        }
    }
}

// MARK: - TrueRetention

public struct TrueRetentionStats: Sendable, Hashable {
    public var today: TrueRetention
    public var yesterday: TrueRetention
    public var week: TrueRetention
    public var month: TrueRetention
    public var year: TrueRetention
    public var allTime: TrueRetention

    public init(
        today: TrueRetention = TrueRetention(),
        yesterday: TrueRetention = TrueRetention(),
        week: TrueRetention = TrueRetention(),
        month: TrueRetention = TrueRetention(),
        year: TrueRetention = TrueRetention(),
        allTime: TrueRetention = TrueRetention()
    ) {
        self.today = today
        self.yesterday = yesterday
        self.week = week
        self.month = month
        self.year = year
        self.allTime = allTime
    }

    public struct TrueRetention: Sendable, Hashable {
        public var youngPassed: Int
        public var youngFailed: Int
        public var maturePassed: Int
        public var matureFailed: Int

        public init(
            youngPassed: Int = 0,
            youngFailed: Int = 0,
            maturePassed: Int = 0,
            matureFailed: Int = 0
        ) {
            self.youngPassed = youngPassed
            self.youngFailed = youngFailed
            self.maturePassed = maturePassed
            self.matureFailed = matureFailed
        }
    }
}
