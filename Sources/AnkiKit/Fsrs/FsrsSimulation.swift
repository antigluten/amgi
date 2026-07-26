/// Inputs for the FSRS simulator (review + workload modes share the
/// same wire request type). Surfaces only the fields that consumers
/// in `DeckConfigView` actually populate — `reviewOrder` and
/// `easyDaysPercentages` keep their proto defaults until the
/// DeckConfig cluster lands.
public struct FsrsSimulationRequest: Sendable, Hashable {
    public let weights: FsrsWeights
    /// Desired retention as a ratio in [0, 1].
    public let desiredRetention: Float
    /// Simulated additional cards beyond the existing deck contents.
    public let additionalCards: Int
    public let daysToSimulate: Int
    public let newLimit: Int
    public let reviewLimit: Int
    public let maxIntervalDays: Int
    public let search: String
    public let newCardsIgnoreReviewLimit: Bool
    /// Historical retention as a ratio in [0, 1].
    public let historicalRetention: Float
    public let learningStepCount: Int
    public let relearningStepCount: Int
    /// Suspend after this many lapses. `nil` disables suspend-on-leech.
    public let suspendAfterLapseCount: Int?

    public init(
        weights: FsrsWeights,
        desiredRetention: Float,
        additionalCards: Int,
        daysToSimulate: Int,
        newLimit: Int,
        reviewLimit: Int,
        maxIntervalDays: Int,
        search: String,
        newCardsIgnoreReviewLimit: Bool,
        historicalRetention: Float,
        learningStepCount: Int,
        relearningStepCount: Int,
        suspendAfterLapseCount: Int?
    ) {
        self.weights = weights
        self.desiredRetention = desiredRetention
        self.additionalCards = additionalCards
        self.daysToSimulate = daysToSimulate
        self.newLimit = newLimit
        self.reviewLimit = reviewLimit
        self.maxIntervalDays = maxIntervalDays
        self.search = search
        self.newCardsIgnoreReviewLimit = newCardsIgnoreReviewLimit
        self.historicalRetention = historicalRetention
        self.learningStepCount = learningStepCount
        self.relearningStepCount = relearningStepCount
        self.suspendAfterLapseCount = suspendAfterLapseCount
    }
}

/// Day-by-day series produced by `simulateFsrsReview`.
public struct FsrsReviewSimulation: Sendable, Hashable {
    public let accumulatedKnowledge: [Float]
    public let dailyNewCount: [Int]
    public let dailyReviewCount: [Int]
    public let dailyTimeCost: [Float]

    public init(
        accumulatedKnowledge: [Float],
        dailyNewCount: [Int],
        dailyReviewCount: [Int],
        dailyTimeCost: [Float]
    ) {
        self.accumulatedKnowledge = accumulatedKnowledge
        self.dailyNewCount = dailyNewCount
        self.dailyReviewCount = dailyReviewCount
        self.dailyTimeCost = dailyTimeCost
    }
}

/// Aggregate retention-vs-cost curves produced by
/// `simulateFsrsWorkload`. Dictionary keys are retention percentages
/// expressed as integers (e.g. `90` for 90%).
public struct FsrsWorkloadSimulation: Sendable, Hashable {
    public let cost: [Int: Float]
    public let memorized: [Int: Float]
    public let reviewCount: [Int: Int]

    public init(
        cost: [Int: Float],
        memorized: [Int: Float],
        reviewCount: [Int: Int]
    ) {
        self.cost = cost
        self.memorized = memorized
        self.reviewCount = reviewCount
    }
}
