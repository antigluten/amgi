//
//  SchedulerLiveTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend

@Suite struct SchedulerLiveTests {
    private func addCard(_ backend: AnkiBackend) throws -> CardID {
        let names = try backend.invoke(.notetypeNames)
        let basic = try #require(names.first { $0.name == "Basic" })
        var template = try backend.invoke(.newNote(notetypeId: basic.id))
        template.fields[0] = "front"
        template.fields[1] = "back"
        try backend.invoke(.addNote(template: template, deckId: DeckID(1)))

        let queued: QueuedCardsResult = try backend.invoke(.getQueuedCards(fetchLimit: 1))
        let noteId = try #require(queued.cards.first?.card.nid)
        return try #require(try backend.invoke(.cardIDsOfNote(id: noteId)).first)
    }

    @Test func setDueDate_promotesANewCardToReview() throws {
        try withScratchCollection("sched-due") { backend, _ in
            let card = try addCard(backend)
            // CardType: 0 = new, 2 = review. CardQueue: 0 = new, 2 = review.
            #expect(try backend.invoke(.getCard(id: card)).type == 0)

            try backend.invoke(.setDueDate(cardIds: [card], days: "5"))

            let rescheduled = try backend.invoke(.getCard(id: card))
            #expect(rescheduled.type == 2, "setDueDate must convert a new card to review")
            #expect(rescheduled.queue == 2)
            #expect(rescheduled.ivl == 5)
        }
    }

    @Test func scheduleCardsAsNew_undoesTheScheduling() throws {
        try withScratchCollection("sched-as-new") { backend, _ in
            let card = try addCard(backend)
            try backend.invoke(.setDueDate(cardIds: [card], days: "5"))
            #expect(try backend.invoke(.getCard(id: card)).type == 2)

            try backend.invoke(.scheduleCardsAsNew(cardIds: [card], log: false))
            #expect(try backend.invoke(.getCard(id: card)).type == 0)
        }
    }

    @Test func answerReviewCard_usesTheStatesFromGetQueuedCards() throws {
        try withScratchCollection("sched-answer-review") { backend, _ in
            _ = try addCard(backend)

            let queued: QueuedCardsResult = try backend.invoke(.getQueuedCards(fetchLimit: 1))
            let entry = try #require(queued.cards.first)
            #expect(entry.card.reps == 0)

            try backend.invoke(
                .answerReviewCard(
                    cardId: entry.card.id,
                    rating: .good,
                    timeSpentMs: 1_500,
                    states: entry.states
                )
            )

            let answered = try backend.invoke(.getCard(id: entry.card.id))
            #expect(answered.reps == 1)
            #expect(answered.type != 0, "an answered new card leaves the new queue")

            let today = try backend.invoke(.graphs(search: "deck:*", days: 31)).today
            #expect(today.answerCount == 1)
        }
    }

    @Test func extendLimits_liftsADeckPinnedToZeroNewCards() throws {
        try withScratchCollection("sched-extend") { backend, _ in
            _ = try addCard(backend)
            #expect(try backend.invoke(.deckCounts(for: DeckID(1)))?.newCount == 1)

            let context = try backend.invoke(.deckConfigsForUpdate(deckId: DeckID(1)))
            var preset = try #require(context.allConfig.first?.config)
            preset.config.newPerDay = 0
            try backend.invoke(
                .updateDeckConfigs(
                    UpdateDeckConfigsRequest(targetDeckID: DeckID(1), configs: [preset])
                )
            )
            #expect(try backend.invoke(.deckCounts(for: DeckID(1)))?.newCount == 0)

            try backend.invoke(.extendLimits(deckId: DeckID(1), newDelta: 1, reviewDelta: 0))
            #expect(try backend.invoke(.deckCounts(for: DeckID(1)))?.newCount == 1)
        }
    }

    @Test func setFlag_andRemoveCards() throws {
        try withScratchCollection("cards-flag") { backend, _ in
            let card = try addCard(backend)
            #expect(try backend.invoke(.getCard(id: card)).flags & 0b111 == 0)

            try backend.invoke(.setFlag(cardIds: [card], flag: 3))
            #expect(try backend.invoke(.getCard(id: card)).flags & 0b111 == 3)

            try backend.invoke(.removeCards(cardIds: [card]))
            #expect(throws: (any Error).self) { try backend.invoke(.getCard(id: card)) }
        }
    }
}
