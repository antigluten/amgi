import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - answerCard (simple — no scheduling state)

extension Request where Response == Void {
    /// Submits an answer without round-tripping scheduling state. The
    /// Rust backend computes the next state from current card data.
    public static func answerCard(cardId: CardID, rating: Rating, timeSpentMs: UInt32) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.answerCard,
            encode: {
                var proto = Anki_Scheduler_CardAnswer()
                proto.cardID = cardId.rawValue
                proto.rating = protoRating(rating)
                proto.answeredAtMillis = Date().ankiMillis
                proto.millisecondsTaken = timeSpentMs
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Submits an answer with pre-computed scheduling states fetched
    /// alongside the queue (via `getQueuedCards`). Token bytes are
    /// passed through opaque — the bridge handles encode/decode.
    public static func answerReviewCard(
        cardId: CardID,
        rating: Rating,
        timeSpentMs: UInt32,
        states: ReviewSchedulingStates
    ) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.answerCard,
            encode: {
                let currentState = try Anki_Scheduler_SchedulingState(serializedBytes: states.current.bytes)
                let newStateBytes: Data = switch rating {
                case .again: states.again.bytes
                case .hard:  states.hard.bytes
                case .good:  states.good.bytes
                case .easy:  states.easy.bytes
                }
                let newState = try Anki_Scheduler_SchedulingState(serializedBytes: newStateBytes)

                var proto = Anki_Scheduler_CardAnswer()
                proto.cardID = cardId.rawValue
                proto.currentState = currentState
                proto.newState = newState
                proto.rating = protoRating(rating)
                proto.answeredAtMillis = Date().ankiMillis
                proto.millisecondsTaken = timeSpentMs
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Empties a filtered deck — moves its cards back to their home
    /// decks and resets the filtered deck to empty.
    public static func emptyFilteredDeck(deckId: DeckID) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.emptyFilteredDeck,
            encode: {
                var proto = Anki_Decks_DeckId()
                proto.did = deckId.rawValue
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Resets the given cards to "new" state. `log: true` records the
    /// operation in the undo stack.
    public static func scheduleCardsAsNew(cardIds: [CardID], log: Bool) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.scheduleCardsAsNew,
            encode: {
                var proto = Anki_Scheduler_ScheduleCardsAsNewRequest()
                proto.cardIds = cardIds.map(\.rawValue)
                proto.log = log
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }
}

// MARK: - rebuildFilteredDeck

extension Request where Response == Int {
    /// Rebuilds a filtered deck and returns the number of cards moved
    /// into it. Wraps `OpChangesWithCount` and surfaces just the count.
    public static func rebuildFilteredDeck(deckId: DeckID) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.rebuildFilteredDeck,
            encode: {
                var proto = Anki_Decks_DeckId()
                proto.did = deckId.rawValue
                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_Collection_OpChangesWithCount(serializedBytes: bytes)
                return Int(resp.count)
            }
        )
    }
}

// MARK: - getQueuedCards

extension Request where Response == QueuedCardsResult {
    /// Returns the next batch of due cards along with pre-computed
    /// scheduling states (opaque tokens) and next-interval display
    /// strings for each rating button.
    public static func getQueuedCards(fetchLimit: UInt32) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.getQueuedCards,
            encode: {
                var proto = Anki_Scheduler_GetQueuedCardsRequest()
                proto.fetchLimit = fetchLimit
                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_Scheduler_QueuedCards(serializedBytes: bytes)
                var cards: [QueuedReviewCard] = []
                for queued in resp.cards {
                    guard queued.hasCard else { continue }
                    let states = ReviewSchedulingStates(
                        current: SchedulingStateToken(try queued.states.current.serializedData()),
                        again:   SchedulingStateToken(try queued.states.again.serializedData()),
                        hard:    SchedulingStateToken(try queued.states.hard.serializedData()),
                        good:    SchedulingStateToken(try queued.states.good.serializedData()),
                        easy:    SchedulingStateToken(try queued.states.easy.serializedData())
                    )
                    let intervals: [Rating: String] = [
                        .again: formatInterval(scheduledSecs(queued.states.again)),
                        .hard:  formatInterval(scheduledSecs(queued.states.hard)),
                        .good:  formatInterval(scheduledSecs(queued.states.good)),
                        .easy:  formatInterval(scheduledSecs(queued.states.easy)),
                    ]
                    cards.append(QueuedReviewCard(
                        card: CardRecord(queued.card),
                        states: states,
                        nextIntervals: intervals
                    ))
                }
                return QueuedCardsResult(
                    cards: cards,
                    newCount: Int(resp.newCount),
                    learningCount: Int(resp.learningCount),
                    reviewCount: Int(resp.reviewCount)
                )
            }
        )
    }
}

// MARK: - computeFsrsParams

extension Request where Response == FsrsOptimizeResult {
    /// Optimizes the FSRS weights for the supplied training set.
    public static func computeFsrsParams(_ input: FsrsOptimizeRequest) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.computeFsrsParams,
            encode: {
                var proto = Anki_Scheduler_ComputeFsrsParamsRequest()
                proto.search = input.search
                proto.currentParams = input.currentWeights.values
                if let cutoff = input.ignoreRevlogsBefore {
                    proto.ignoreRevlogsBeforeMs = cutoff.ankiMillis
                }
                proto.numOfRelearningSteps = UInt32(max(0, input.relearningStepsPerDay))
                proto.healthCheck = input.runHealthCheck
                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_Scheduler_ComputeFsrsParamsResponse(serializedBytes: bytes)
                return FsrsOptimizeResult(
                    weights: FsrsWeights(resp.params),
                    trainingItemCount: Int(resp.fsrsItems),
                    healthCheck: resp.hasHealthCheckPassed
                        ? (resp.healthCheckPassed ? .passed : .failed)
                        : nil
                )
            }
        )
    }
}

// MARK: - simulateFsrsReview

extension Request where Response == FsrsReviewSimulation {
    public static func simulateFsrsReview(_ input: FsrsSimulationRequest) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.simulateFsrsReview,
            encode: { try makeSimulationProto(input).serializedData() },
            decode: { bytes in
                let resp = try Anki_Scheduler_SimulateFsrsReviewResponse(serializedBytes: bytes)
                return FsrsReviewSimulation(
                    accumulatedKnowledge: resp.accumulatedKnowledgeAcquisition,
                    dailyNewCount: resp.dailyNewCount.map(Int.init),
                    dailyReviewCount: resp.dailyReviewCount.map(Int.init),
                    dailyTimeCost: resp.dailyTimeCost
                )
            }
        )
    }
}

// MARK: - simulateFsrsWorkload

extension Request where Response == FsrsWorkloadSimulation {
    public static func simulateFsrsWorkload(_ input: FsrsSimulationRequest) -> Self {
        Self(
            serviceId: ServiceID.scheduler,
            methodId: SchedulerMethod.simulateFsrsWorkload,
            encode: { try makeSimulationProto(input).serializedData() },
            decode: { bytes in
                let resp = try Anki_Scheduler_SimulateFsrsWorkloadResponse(serializedBytes: bytes)
                return FsrsWorkloadSimulation(
                    cost: Dictionary(uniqueKeysWithValues: resp.cost.map { (Int($0.key), $0.value) }),
                    memorized: Dictionary(uniqueKeysWithValues: resp.memorized.map { (Int($0.key), $0.value) }),
                    reviewCount: Dictionary(uniqueKeysWithValues: resp.reviewCount.map { (Int($0.key), Int($0.value)) })
                )
            }
        )
    }
}

// MARK: - Shared encoder

private func makeSimulationProto(_ input: FsrsSimulationRequest) -> Anki_Scheduler_SimulateFsrsReviewRequest {
    var proto = Anki_Scheduler_SimulateFsrsReviewRequest()
    proto.params = input.weights.values
    proto.desiredRetention = input.desiredRetention
    proto.deckSize = UInt32(max(0, input.additionalCards))
    proto.daysToSimulate = UInt32(max(1, input.daysToSimulate))
    proto.newLimit = UInt32(max(0, input.newLimit))
    proto.reviewLimit = UInt32(max(0, input.reviewLimit))
    proto.maxInterval = UInt32(max(1, input.maxIntervalDays))
    proto.search = input.search
    proto.newCardsIgnoreReviewLimit = input.newCardsIgnoreReviewLimit
    proto.historicalRetention = input.historicalRetention
    proto.learningStepCount = UInt32(max(0, input.learningStepCount))
    proto.relearningStepCount = UInt32(max(0, input.relearningStepCount))
    if let suspend = input.suspendAfterLapseCount {
        proto.suspendAfterLapseCount = UInt32(max(1, suspend))
    }
    return proto
}
