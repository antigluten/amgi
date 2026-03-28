public struct SessionStats: Sendable, Equatable {
    public var reviewed: Int
    public var correct: Int
    public var totalTimeMs: Int

    public var accuracy: Double {
        reviewed > 0 ? Double(correct) / Double(reviewed) : 0
    }

    public init(reviewed: Int = 0, correct: Int = 0, totalTimeMs: Int = 0) {
        self.reviewed = reviewed
        self.correct = correct
        self.totalTimeMs = totalTimeMs
    }
}
