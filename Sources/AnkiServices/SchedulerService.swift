import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SchedulerService: Sendable {
    /// Simple answer — rating + time, no scheduling-state round-trip.
    public var answerCard: @Sendable (_ cardId: CardID, _ rating: Rating, _ timeSpent: Int32) throws -> Void
    /// Full queue fetch including scheduling states and pre-computed next intervals.
    public var getQueuedCards: @Sendable (_ fetchLimit: Int32) throws -> QueuedCardsResult
    /// Answer with scheduling states previously returned by getQueuedCards.
    public var answerReviewCard: @Sendable (_ cardId: CardID, _ rating: Rating, _ timeSpent: UInt32, _ states: ReviewSchedulingStates) throws -> Void
}

extension SchedulerService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            answerCard: { cardId, rating, timeSpent in
                try backend.invoke(.answerCard(
                    cardId: cardId, rating: rating, timeSpentMs: UInt32(max(0, timeSpent))
                ))
            },
            getQueuedCards: { fetchLimit in
                try backend.invoke(.getQueuedCards(fetchLimit: UInt32(max(0, fetchLimit))))
            },
            answerReviewCard: { cardId, rating, timeSpent, states in
                try backend.invoke(.answerReviewCard(
                    cardId: cardId, rating: rating, timeSpentMs: timeSpent, states: states
                ))
            }
        )
    }()
}

extension SchedulerService: TestDependencyKey {
    public static let testValue = SchedulerService()
}

extension DependencyValues {
    public var schedulerService: SchedulerService {
        get { self[SchedulerService.self] }
        set { self[SchedulerService.self] = newValue }
    }
}
