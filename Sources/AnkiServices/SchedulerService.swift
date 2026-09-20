//
//  SchedulerService.swift
//  AnkiServices
//
//  Created by Vladimir Gusev on 01.04.2026.
//

import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SchedulerService: Sendable {
    /// Full queue fetch including scheduling states and pre-computed next intervals.
    public var getQueuedCards: @Sendable (_ fetchLimit: Int32) throws -> QueuedCardsResult
    /// Answer with scheduling states previously returned by getQueuedCards.
    public var answerReviewCard: @Sendable (_ cardId: CardID, _ rating: Rating, _ timeSpent: UInt32, _ states: ReviewSchedulingStates) throws -> Void
}

extension SchedulerService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
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
