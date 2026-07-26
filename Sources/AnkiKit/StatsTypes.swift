public struct TodayStats: Sendable, Equatable {
    public var reviewed: Int
    public var timeSpentMs: Int
    public var newCards: Int
    public var learnCards: Int
    public var reviewCards: Int
    public var againCount: Int

    public init(
        reviewed: Int = 0, timeSpentMs: Int = 0, newCards: Int = 0,
        learnCards: Int = 0, reviewCards: Int = 0, againCount: Int = 0
    ) {
        self.reviewed = reviewed
        self.timeSpentMs = timeSpentMs
        self.newCards = newCards
        self.learnCards = learnCards
        self.reviewCards = reviewCards
        self.againCount = againCount
    }
}

public struct HourCount: Sendable, Equatable {
    public let hour: Int
    public let count: Int

    public init(hour: Int, count: Int) {
        self.hour = hour
        self.count = count
    }
}
