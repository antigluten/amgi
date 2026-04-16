package import Foundation

/// Opaque wrapper for a serialized proto SchedulingState. App code holds these
/// but cannot inspect them; AnkiServices reads/writes the bytes internally.
public struct SchedulingStateToken: Sendable {
    package let bytes: Data
    package init(_ bytes: Data) { self.bytes = bytes }
}

public struct ReviewSchedulingStates: Sendable {
    public let current: SchedulingStateToken
    public let again: SchedulingStateToken
    public let hard: SchedulingStateToken
    public let good: SchedulingStateToken
    public let easy: SchedulingStateToken

    package init(
        current: SchedulingStateToken,
        again: SchedulingStateToken,
        hard: SchedulingStateToken,
        good: SchedulingStateToken,
        easy: SchedulingStateToken
    ) {
        self.current = current
        self.again = again
        self.hard = hard
        self.good = good
        self.easy = easy
    }
}

public struct QueuedReviewCard: Sendable {
    public let card: CardRecord
    public let states: ReviewSchedulingStates
    public let nextIntervals: [Rating: String]

    package init(card: CardRecord, states: ReviewSchedulingStates, nextIntervals: [Rating: String]) {
        self.card = card
        self.states = states
        self.nextIntervals = nextIntervals
    }
}

public struct QueuedCardsResult: Sendable {
    public let cards: [QueuedReviewCard]
    public let newCount: Int
    public let learningCount: Int
    public let reviewCount: Int

    package init(cards: [QueuedReviewCard], newCount: Int, learningCount: Int, reviewCount: Int) {
        self.cards = cards
        self.newCount = newCount
        self.learningCount = learningCount
        self.reviewCount = reviewCount
    }
}

public struct RenderedCard: Sendable {
    public let frontHTML: String
    public let backHTML: String

    package init(frontHTML: String, backHTML: String) {
        self.frontHTML = frontHTML
        self.backHTML = backHTML
    }
}
