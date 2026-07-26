import Testing
import Foundation
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct SchedulerRequestsTests {
    // MARK: - answerCard (simple)

    @Test func answerCard_dispatches_to_scheduler_answer() {
        let envelope: Request<Void> = .answerCard(cardId: CardID(42), rating: .good, timeSpentMs: 1500)
        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.answerCard)
    }

    @Test func answerCard_encodes_cardId_rating_and_time() throws {
        let envelope: Request<Void> = .answerCard(cardId: CardID(42), rating: .easy, timeSpentMs: 2500)
        let proto = try Anki_Scheduler_CardAnswer(serializedBytes: envelope.body)
        #expect(proto.cardID == 42)
        #expect(proto.rating == .easy)
        #expect(proto.millisecondsTaken == 2500)
        #expect(proto.answeredAtMillis > 0)
    }

    @Test func answerCard_rating_mapping_covers_all_cases() throws {
        let cases: [(Rating, Anki_Scheduler_CardAnswer.Rating)] = [
            (.again, .again), (.hard, .hard), (.good, .good), (.easy, .easy),
        ]
        for (rating, expected) in cases {
            let envelope: Request<Void> = .answerCard(cardId: CardID(1), rating: rating, timeSpentMs: 0)
            let proto = try Anki_Scheduler_CardAnswer(serializedBytes: envelope.body)
            #expect(proto.rating == expected, "rating \(rating) should map to proto \(expected)")
        }
    }

    // MARK: - answerReviewCard (with states)

    @Test func answerReviewCard_encodes_currentState_and_picks_newState_by_rating() throws {
        let states = try makeStates()
        let envelope: Request<Void> = .answerReviewCard(
            cardId: CardID(7), rating: .hard, timeSpentMs: 1234, states: states
        )
        let proto = try Anki_Scheduler_CardAnswer(serializedBytes: envelope.body)
        #expect(proto.cardID == 7)
        #expect(proto.rating == .hard)
        #expect(proto.millisecondsTaken == 1234)
        #expect(proto.hasCurrentState)
        #expect(proto.hasNewState)
        // hard branch in fixture sets scheduled_days = 2
        #expect(proto.newState.normal.review.scheduledDays == 2)
    }

    @Test func answerReviewCard_newState_branches_per_rating() throws {
        let states = try makeStates()
        let mapping: [(Rating, UInt32)] = [
            (.again, 0), (.hard, 2), (.good, 7), (.easy, 30),
        ]
        for (rating, expectedDays) in mapping {
            let envelope: Request<Void> = .answerReviewCard(
                cardId: CardID(1), rating: rating, timeSpentMs: 0, states: states
            )
            let proto = try Anki_Scheduler_CardAnswer(serializedBytes: envelope.body)
            #expect(
                proto.newState.normal.review.scheduledDays == expectedDays,
                "rating \(rating) should pick the matching state branch"
            )
        }
    }

    // MARK: - rebuildFilteredDeck / emptyFilteredDeck

    @Test func rebuildFilteredDeck_dispatches_and_encodes_deckId() throws {
        let envelope: Request<Int> = .rebuildFilteredDeck(deckId: DeckID(99))
        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.rebuildFilteredDeck)
        let proto = try Anki_Decks_DeckId(serializedBytes: envelope.body)
        #expect(proto.did == 99)
    }

    @Test func rebuildFilteredDeck_decodes_count() throws {
        var resp = Anki_Collection_OpChangesWithCount()
        resp.count = 17
        let bytes = try resp.serializedData()
        let envelope: Request<Int> = .rebuildFilteredDeck(deckId: DeckID(1))
        #expect(try envelope.decode(bytes) == 17)
    }

    @Test func emptyFilteredDeck_dispatches_and_encodes_deckId() throws {
        let envelope: Request<Void> = .emptyFilteredDeck(deckId: DeckID(33))
        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.emptyFilteredDeck)
        let proto = try Anki_Decks_DeckId(serializedBytes: envelope.body)
        #expect(proto.did == 33)
    }

    // MARK: - scheduleCardsAsNew

    @Test func scheduleCardsAsNew_dispatches_and_encodes_ids_and_log_flag() throws {
        let envelope: Request<Void> = .scheduleCardsAsNew(
            cardIds: [CardID(1), CardID(2), CardID(3)], log: true
        )
        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.scheduleCardsAsNew)
        let proto = try Anki_Scheduler_ScheduleCardsAsNewRequest(serializedBytes: envelope.body)
        #expect(proto.cardIds == [1, 2, 3])
        #expect(proto.log)
    }

    // MARK: - getQueuedCards

    @Test func getQueuedCards_dispatches_to_scheduler_getQueuedCards() {
        let envelope: Request<QueuedCardsResult> = .getQueuedCards(fetchLimit: 200)
        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.getQueuedCards)
    }

    @Test func getQueuedCards_encodes_fetchLimit() throws {
        let envelope: Request<QueuedCardsResult> = .getQueuedCards(fetchLimit: 50)
        let proto = try Anki_Scheduler_GetQueuedCardsRequest(serializedBytes: envelope.body)
        #expect(proto.fetchLimit == 50)
    }

    @Test func getQueuedCards_decodes_counts_and_card_mapping() throws {
        var card = Anki_Cards_Card()
        card.id = 100
        card.noteID = 200
        card.deckID = 1
        card.templateIdx = 0
        card.mtimeSecs = 999
        card.queue = 2
        card.ctype = 2
        card.interval = 5
        card.reps = 3

        let states = try makeQueuedStates()
        var queued = Anki_Scheduler_QueuedCards.QueuedCard()
        queued.card = card
        queued.states = states

        var resp = Anki_Scheduler_QueuedCards()
        resp.cards = [queued]
        resp.newCount = 4
        resp.learningCount = 5
        resp.reviewCount = 6
        let bytes = try resp.serializedData()

        let envelope: Request<QueuedCardsResult> = .getQueuedCards(fetchLimit: 1)
        let result = try envelope.decode(bytes)

        #expect(result.newCount == 4)
        #expect(result.learningCount == 5)
        #expect(result.reviewCount == 6)
        #expect(result.cards.count == 1)
        let queuedCard = try #require(result.cards.first)
        #expect(queuedCard.card.id == CardID(100))
        #expect(queuedCard.card.nid == NoteID(200))
        #expect(queuedCard.card.ivl == 5)
        #expect(queuedCard.card.reps == 3)
        // hard = 2 days → "2d"
        #expect(queuedCard.nextIntervals[.hard] == "2d")
        // good = 7 days → "7d"
        #expect(queuedCard.nextIntervals[.good] == "7d")
    }

    @Test func getQueuedCards_skips_cards_without_card_field() throws {
        var resp = Anki_Scheduler_QueuedCards()
        // QueuedCard with no `card` field set — should be skipped
        resp.cards = [Anki_Scheduler_QueuedCards.QueuedCard()]
        let bytes = try resp.serializedData()
        let envelope: Request<QueuedCardsResult> = .getQueuedCards(fetchLimit: 1)
        let result = try envelope.decode(bytes)
        #expect(result.cards.isEmpty)
    }

    // MARK: - computeFsrsParams

    @Test func computeFsrsParams_dispatches_to_scheduler_service_and_method() {
        let request = makeOptimizeRequest()
        let envelope: Request<FsrsOptimizeResult> = .computeFsrsParams(request)

        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.computeFsrsParams)
    }

    @Test func computeFsrsParams_encodes_request_fields() throws {
        let cutoff = Date(timeIntervalSince1970: 1_700_000_000)
        let request = FsrsOptimizeRequest(
            search: "deck:Korean",
            currentWeights: FsrsWeights([0.1, 0.2, 0.3]),
            ignoreRevlogsBefore: cutoff,
            relearningStepsPerDay: 4,
            runHealthCheck: true
        )

        let envelope: Request<FsrsOptimizeResult> = .computeFsrsParams(request)
        let proto = try Anki_Scheduler_ComputeFsrsParamsRequest(serializedBytes: envelope.body)

        #expect(proto.search == "deck:Korean")
        #expect(proto.currentParams == [0.1, 0.2, 0.3])
        #expect(proto.ignoreRevlogsBeforeMs == 1_700_000_000_000)
        #expect(proto.numOfRelearningSteps == 4)
        #expect(proto.healthCheck)
    }

    @Test func computeFsrsParams_skips_ignoreRevlogsBefore_when_nil() throws {
        let request = makeOptimizeRequest(ignoreRevlogsBefore: nil)
        let envelope: Request<FsrsOptimizeResult> = .computeFsrsParams(request)
        let proto = try Anki_Scheduler_ComputeFsrsParamsRequest(serializedBytes: envelope.body)
        #expect(proto.ignoreRevlogsBeforeMs == 0)
    }

    @Test func computeFsrsParams_decodes_response_with_passed_health_check() throws {
        var resp = Anki_Scheduler_ComputeFsrsParamsResponse()
        resp.params = [0.4, 0.5]
        resp.fsrsItems = 1234
        resp.healthCheckPassed = true
        let bytes = try resp.serializedData()

        let envelope: Request<FsrsOptimizeResult> = .computeFsrsParams(makeOptimizeRequest())
        let result = try envelope.decode(bytes)

        #expect(result.weights.values == [0.4, 0.5])
        #expect(result.trainingItemCount == 1234)
        #expect(result.healthCheck == .passed)
    }

    @Test func computeFsrsParams_decodes_response_with_failed_health_check() throws {
        var resp = Anki_Scheduler_ComputeFsrsParamsResponse()
        resp.healthCheckPassed = false
        let bytes = try resp.serializedData()

        let envelope: Request<FsrsOptimizeResult> = .computeFsrsParams(makeOptimizeRequest())
        let result = try envelope.decode(bytes)

        #expect(result.healthCheck == .failed)
    }

    @Test func computeFsrsParams_decodes_response_with_no_health_check_as_nil() throws {
        let resp = Anki_Scheduler_ComputeFsrsParamsResponse()
        let bytes = try resp.serializedData()

        let envelope: Request<FsrsOptimizeResult> = .computeFsrsParams(makeOptimizeRequest())
        let result = try envelope.decode(bytes)

        #expect(result.healthCheck == nil)
    }

    // MARK: - simulateFsrsReview

    @Test func simulateFsrsReview_dispatches_to_scheduler_simulateReview() {
        let envelope: Request<FsrsReviewSimulation> = .simulateFsrsReview(makeSimulationRequest())
        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.simulateFsrsReview)
    }

    @Test func simulateFsrsReview_encodes_full_request() throws {
        let envelope: Request<FsrsReviewSimulation> = .simulateFsrsReview(makeSimulationRequest(suspendAfterLapseCount: 7))
        let proto = try Anki_Scheduler_SimulateFsrsReviewRequest(serializedBytes: envelope.body)

        #expect(proto.params == [0.1, 0.2])
        #expect(proto.desiredRetention == 0.9)
        #expect(proto.deckSize == 100)
        #expect(proto.daysToSimulate == 30)
        #expect(proto.newLimit == 20)
        #expect(proto.reviewLimit == 200)
        #expect(proto.maxInterval == 36500)
        #expect(proto.search == "deck:Korean")
        #expect(proto.newCardsIgnoreReviewLimit)
        #expect(proto.historicalRetention == 0.85)
        #expect(proto.learningStepCount == 2)
        #expect(proto.relearningStepCount == 1)
        #expect(proto.hasSuspendAfterLapseCount)
        #expect(proto.suspendAfterLapseCount == 7)
    }

    @Test func simulateFsrsReview_skips_suspendAfterLapseCount_when_nil() throws {
        let envelope: Request<FsrsReviewSimulation> = .simulateFsrsReview(makeSimulationRequest(suspendAfterLapseCount: nil))
        let proto = try Anki_Scheduler_SimulateFsrsReviewRequest(serializedBytes: envelope.body)
        #expect(!proto.hasSuspendAfterLapseCount)
    }

    @Test func simulateFsrsReview_decodes_daily_series() throws {
        var resp = Anki_Scheduler_SimulateFsrsReviewResponse()
        resp.accumulatedKnowledgeAcquisition = [0.1, 0.5, 0.9]
        resp.dailyNewCount = [10, 5, 3]
        resp.dailyReviewCount = [20, 30, 40]
        resp.dailyTimeCost = [60, 90, 120]
        let bytes = try resp.serializedData()

        let envelope: Request<FsrsReviewSimulation> = .simulateFsrsReview(makeSimulationRequest())
        let result = try envelope.decode(bytes)

        #expect(result.accumulatedKnowledge == [0.1, 0.5, 0.9])
        #expect(result.dailyNewCount == [10, 5, 3])
        #expect(result.dailyReviewCount == [20, 30, 40])
        #expect(result.dailyTimeCost == [60, 90, 120])
    }

    // MARK: - simulateFsrsWorkload

    @Test func simulateFsrsWorkload_dispatches_to_scheduler_simulateWorkload() {
        let envelope: Request<FsrsWorkloadSimulation> = .simulateFsrsWorkload(makeSimulationRequest())
        #expect(envelope.serviceId == ServiceID.scheduler)
        #expect(envelope.methodId == SchedulerMethod.simulateFsrsWorkload)
    }

    @Test func simulateFsrsWorkload_decodes_dictionaries() throws {
        var resp = Anki_Scheduler_SimulateFsrsWorkloadResponse()
        resp.cost = [85: 1.5, 90: 2.5]
        resp.memorized = [85: 100, 90: 120]
        resp.reviewCount = [85: 50, 90: 80]
        let bytes = try resp.serializedData()

        let envelope: Request<FsrsWorkloadSimulation> = .simulateFsrsWorkload(makeSimulationRequest())
        let result = try envelope.decode(bytes)

        #expect(result.cost[85] == 1.5)
        #expect(result.cost[90] == 2.5)
        #expect(result.memorized[85] == 100)
        #expect(result.reviewCount[85] == 50)
        #expect(result.reviewCount[90] == 80)
    }

    // MARK: - Helpers

    /// Builds a `ReviewSchedulingStates` whose four rating-branch tokens
    /// decode to `SchedulingState.Normal.Review` with distinct `scheduledDays`
    /// (again=0, hard=2, good=7, easy=30) so tests can assert the rating-to-
    /// branch mapping precisely.
    private func makeStates() throws -> ReviewSchedulingStates {
        func state(days: UInt32) throws -> SchedulingStateToken {
            var review = Anki_Scheduler_SchedulingState.Review()
            review.scheduledDays = days
            var normal = Anki_Scheduler_SchedulingState.Normal()
            normal.review = review
            var s = Anki_Scheduler_SchedulingState()
            s.normal = normal
            return SchedulingStateToken(try s.serializedData())
        }
        return ReviewSchedulingStates(
            current: try state(days: 1),
            again:   try state(days: 0),
            hard:    try state(days: 2),
            good:    try state(days: 7),
            easy:    try state(days: 30)
        )
    }

    /// Builds a `QueuedCards.SchedulingStates` proto matching `makeStates()`,
    /// so `getQueuedCards` decode tests get the same scheduled-days mapping.
    private func makeQueuedStates() throws -> Anki_Scheduler_SchedulingStates {
        func state(days: UInt32) -> Anki_Scheduler_SchedulingState {
            var review = Anki_Scheduler_SchedulingState.Review()
            review.scheduledDays = days
            var normal = Anki_Scheduler_SchedulingState.Normal()
            normal.review = review
            var s = Anki_Scheduler_SchedulingState()
            s.normal = normal
            return s
        }
        var states = Anki_Scheduler_SchedulingStates()
        states.current = state(days: 1)
        states.again   = state(days: 0)
        states.hard    = state(days: 2)
        states.good    = state(days: 7)
        states.easy    = state(days: 30)
        return states
    }

    private func makeOptimizeRequest(
        ignoreRevlogsBefore: Date? = Date(timeIntervalSince1970: 0)
    ) -> FsrsOptimizeRequest {
        FsrsOptimizeRequest(
            search: "deck:test",
            currentWeights: FsrsWeights([0.1]),
            ignoreRevlogsBefore: ignoreRevlogsBefore,
            relearningStepsPerDay: 1,
            runHealthCheck: false
        )
    }

    private func makeSimulationRequest(suspendAfterLapseCount: Int? = nil) -> FsrsSimulationRequest {
        FsrsSimulationRequest(
            weights: FsrsWeights([0.1, 0.2]),
            desiredRetention: 0.9,
            additionalCards: 100,
            daysToSimulate: 30,
            newLimit: 20,
            reviewLimit: 200,
            maxIntervalDays: 36500,
            search: "deck:Korean",
            newCardsIgnoreReviewLimit: true,
            historicalRetention: 0.85,
            learningStepCount: 2,
            relearningStepCount: 1,
            suspendAfterLapseCount: suspendAfterLapseCount
        )
    }
}
