//
//  ReviewSessionTests.swift
//  AmgiAppTests
//
//  Created by Vladimir Gusev on 01.05.2026.
//

import Testing
import SwiftUI
import UIKit
import Dependencies
import Foundation
import AnkiKit
import AnkiServices
@testable import AmgiApp
@testable import ReviewCore

// MARK: - ReviewSessionTests
// Lifted from ~/Clones/amgi/AnkiApp/Sources/Review/ReviewSessionTests.swift (82 LOC)
// Adapted to our architecture: @MainActor class, async revealAnswer(), swift-dependencies mocking.
//
// Migrated from XCTest -> Swift Testing. Per-test setUp/tearDown is replaced
// by per-instance `init` — Swift Testing creates a fresh `ReviewSessionTests`
// instance for every `@Test` method, so `session` is reinitialised cleanly.

@MainActor
@Suite struct ReviewSessionTests {
    let session: ReviewSession

    init() {
        session = ReviewSession(deckId: DeckID(1))
    }

    /// Polls `condition` instead of racing a fixed sleep against
    /// `ReviewSession.start()`'s off-main-actor async chain — avoids
    /// flaking when that chain takes longer than a hardcoded delay.
    private func pollUntil(
        timeout: Duration = .milliseconds(2000),
        interval: Duration = .milliseconds(5),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            if ContinuousClock.now >= deadline { return }
            try await Task.sleep(for: interval)
        }
    }

    // MARK: - Deferred from fork

    // DEFERRED: fork's testCurrentCardInitiallyNil / testCurrentCardPublicAccess /
    // testCurrentCardStructure test `session.currentCard` — a public property in the
    // fork's ReviewSession. Our ReviewSession exposes `currentCardOrdinal: UInt32`
    // but keeps `currentQueuedCard` private. Exposing it would require a public accessor
    // that PR 1a did not add. Use `currentCardOrdinal == 0` as a proxy.
    // PR 1a defer: add `public private(set) var currentCard: QueuedReviewCard?` when needed.

    // MARK: - Property Exposure Tests

    /// currentCardOrdinal should be 0 before the session starts (maps to fork's currentCard == nil).
    @Test func currentCardOrdinalInitiallyZero() {
        #expect(session.currentCardOrdinal == 0,
                "currentCardOrdinal should be 0 before session starts")
    }

    // MARK: - Initial State Tests

    /// Session stats should all be zero-initialised (mirrors fork's testSessionStatsInitialized).
    @Test func sessionStatsInitialized() {
        #expect(session.sessionStats.reviewed == 0, "Initial reviewed count should be 0")
        #expect(session.sessionStats.correct == 0, "Initial correct count should be 0")
        #expect(session.sessionStats.totalTimeMs == 0, "Initial time should be 0")
    }

    /// Remaining counts should be zero before start() (mirrors fork's testRemainingCountsInitialized).
    @Test func remainingCountsInitialized() {
        #expect(session.remainingCounts.newCount == 0)
        #expect(session.remainingCounts.learnCount == 0)
        #expect(session.remainingCounts.reviewCount == 0)
    }

    /// nextIntervals should be empty before any card is loaded (mirrors fork's testNextIntervalsStructure).
    @Test func nextIntervalsStructure() {
        #expect(session.nextIntervals.isEmpty,
                "nextIntervals should be empty initially")
    }

    /// isFinished should be false before start() (mirrors fork's testIsFinishedInitiallyFalse).
    @Test func isFinishedInitiallyFalse() {
        #expect(!session.isFinished, "Session should not be finished initially")
    }

    /// showAnswer should be false before any card is loaded (mirrors fork's testShowAnswerInitiallyFalse).
    @Test func showAnswerInitiallyFalse() {
        #expect(!session.showAnswer, "Answer should not be visible initially")
    }

    // MARK: - Additional initial-state checks (not in fork; added to fill gaps)

    @Test func canUndoInitiallyFalse() {
        #expect(!session.canUndo,
                "canUndo should be false before any card is answered")
    }

    @Test func frontHTMLInitiallyEmpty() {
        #expect(session.frontHTML.isEmpty,
                "frontHTML should be empty before session starts")
    }

    @Test func backHTMLInitiallyEmpty() {
        #expect(session.backHTML.isEmpty,
                "backHTML should be empty before session starts")
    }

    @Test func cardCSSInitiallyEmpty() {
        #expect(session.cardCSS.isEmpty,
                "cardCSS should be empty before session starts")
    }

    @Test func requiresTypedAnswerInputInitiallyFalse() {
        #expect(!session.requiresTypedAnswerInput,
                "requiresTypedAnswerInput should be false initially")
    }

    // MARK: - start() with empty queue

    /// When the scheduler returns an empty queue, start() should mark the session finished.
    /// start() now runs its backend chain off the main actor in an internal Task, so the
    /// assertion waits for that work to settle.
    @Test func startWithEmptyQueueFinishesSession() async throws {
        try await withDependencies {
            $0.decksService.setCurrentDeck = { _ in }
            $0.schedulerService.getQueuedCards = { _ in
                QueuedCardsResult(cards: [], newCount: 0, learningCount: 0, reviewCount: 0)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(42))
            s.start()
            try await pollUntil { s.isFinished && !s.isAdvancing }
            #expect(s.isFinished,
                    "Session with empty queue should be finished after start()")
            #expect(s.remainingCounts == .zero)
            #expect(!s.isAdvancing, "isAdvancing should clear once start() settles")
        }
    }

    // MARK: - revealAnswer() sets showAnswer

    /// revealAnswer() when there is no typed-answer placeholder should set showAnswer = true.
    /// Tests the async path without needing a running card queue.
    @Test func revealAnswerSetsShowAnswer() async {
        // No typedAnswerState is set (no cards loaded), so revealAnswer() takes
        // the non-typed branch and immediately sets showAnswer = true.
        #expect(!session.showAnswer)
        await session.revealAnswer()
        #expect(session.showAnswer,
                "showAnswer should be true after revealAnswer() with no typed-answer state")
    }

    // MARK: - Audio / Chrome state (Task 2)

    @Test func updateAudioPlayingFlipsObservableFlag() {
        let session = ReviewSession(deckId: DeckID(1))
        #expect(!session.isAudioPlaying)
        session.updateAudioPlaying(true)
        #expect(session.isAudioPlaying)
        session.updateAudioPlaying(false)
        #expect(!session.isAudioPlaying)
    }

    @Test func updateCardChromeStoresColorAndDarkness() {
        let session = ReviewSession(deckId: DeckID(1))
        #expect(session.cardChromeColor == .clear)
        #expect(!session.cardChromeIsDark)
        session.updateCardChrome(color: .red, isDark: false)
        #expect(session.cardChromeColor == .red)
        #expect(!session.cardChromeIsDark)
        session.updateCardChrome(color: .black, isDark: true)
        #expect(session.cardChromeColor == .black)
        #expect(session.cardChromeIsDark)
    }

    // MARK: - Replay / Stop-audio bump mutators (Task 3)

    @Test func bumpReplayRequestIncrementsCounter() {
        let session = ReviewSession(deckId: DeckID(1))
        #expect(session.replayRequestID == 0)
        session.bumpReplayRequest()
        #expect(session.replayRequestID == 1)
        session.bumpReplayRequest()
        #expect(session.replayRequestID == 2)
    }

    @Test func bumpStopAudioRequestIncrementsCounter() {
        let session = ReviewSession(deckId: DeckID(1))
        #expect(session.stopAudioRequestID == 0)
        session.bumpStopAudioRequest()
        #expect(session.stopAudioRequestID == 1)
    }

    // MARK: - currentNote cache + TemplateTarget (Task 4)

    @Test func currentNoteCachedOnAdvance() async throws {
        final class Counter: @unchecked Sendable { var value = 0 }
        let callCounter = Counter()
        let stubNote = NoteRecord(
            id: NoteID(100), guid: "g", mid: NotetypeID(200), mod: 0,
            flds: "", sfld: "", csum: 0
        )
        let stubCard = QueuedReviewCard.preview(cardId: CardID(1), noteId: NoteID(100), ord: 0)
        let stubResult = QueuedCardsResult(
            cards: [stubCard], newCount: 1, learningCount: 0, reviewCount: 0
        )

        try await withDependencies {
            $0.notesService.getNote = { noteId in
                callCounter.value += 1
                #expect(noteId == NoteID(100))
                return stubNote
            }
            $0.schedulerService.getQueuedCards = { _ in stubResult }
            $0.cardRenderingService.renderCard = { _ in
                RenderedCard(frontHTML: "<p>front</p>", backHTML: "<p>back</p>", cardCSS: "")
            }
            $0.decksService.setCurrentDeck = { _ in }
            $0.decksService.getCurrentDeck = { DeckInfo(id: DeckID(1), name: "Deck") }
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))
            session.start()
            try await pollUntil { session.currentNote != nil }
            #expect(session.currentNote == stubNote)
            #expect(callCounter.value == 1, "getNote should be called exactly once per advance")

            // Re-observe currentNote — must not trigger additional fetches
            _ = session.currentNote
            _ = session.currentNote
            #expect(callCounter.value == 1, "currentNote is cached, not refetched on observation")
        }
    }

    @Test func currentTemplateTargetDerivedFromCachedNoteAndCard() async throws {
        let stubNote = NoteRecord(
            id: NoteID(100), guid: "g", mid: NotetypeID(200), mod: 0,
            flds: "", sfld: "", csum: 0
        )
        let stubCard = QueuedReviewCard.preview(cardId: CardID(1), noteId: NoteID(100), ord: 3)
        let stubResult = QueuedCardsResult(
            cards: [stubCard], newCount: 1, learningCount: 0, reviewCount: 0
        )

        try await withDependencies {
            $0.notesService.getNote = { _ in stubNote }
            $0.schedulerService.getQueuedCards = { _ in stubResult }
            $0.cardRenderingService.renderCard = { _ in
                RenderedCard(frontHTML: "f", backHTML: "b", cardCSS: "")
            }
            $0.decksService.setCurrentDeck = { _ in }
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))
            session.start()
            try await pollUntil { !session.isAdvancing }
            let target = session.currentTemplateTarget
            #expect(target != nil)
            #expect(target?.notetypeId == NotetypeID(200))
            #expect(target?.ordinal == 3)
        }
    }

    // MARK: - Full audio/chrome round-trip (Task 11)

    @Test func fullAudioAndChromeRoundTrip() async throws {
        let stubCard = QueuedReviewCard.preview(cardId: CardID(1), noteId: NoteID(100), ord: 0)
        let stubResult = QueuedCardsResult(
            cards: [stubCard], newCount: 1, learningCount: 0, reviewCount: 0
        )
        let stubNote = NoteRecord(id: NoteID(100), guid: "g", mid: NotetypeID(200), mod: 0, flds: "", sfld: "", csum: 0)

        try await withDependencies {
            $0.notesService.getNote = { _ in stubNote }
            $0.schedulerService.getQueuedCards = { _ in stubResult }
            $0.cardRenderingService.renderCard = { _ in
                RenderedCard(frontHTML: "f", backHTML: "b", cardCSS: "")
            }
            $0.decksService.setCurrentDeck = { _ in }
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))
            session.start()
            try await pollUntil { !session.isAdvancing }

            // Audio start
            session.updateAudioPlaying(true)
            #expect(session.isAudioPlaying)

            // Capture baseline: advance() already bumped stopAudioRequestID once on card load
            let stopBaselineID = session.stopAudioRequestID

            // User taps replay-while-playing → stop bump (toolbar logic, here exercised manually)
            session.bumpStopAudioRequest()
            #expect(session.stopAudioRequestID == stopBaselineID + 1)

            // JS replies to amgiStopAllAudio → onAudioStateChange(false)
            session.updateAudioPlaying(false)
            #expect(!session.isAudioPlaying)

            // User taps replay again → replay bump
            session.bumpReplayRequest()
            #expect(session.replayRequestID == 1)

            // JS reports a card-bg color
            session.updateCardChrome(color: .blue, isDark: false)
            #expect(session.cardChromeColor == .blue)
        }
    }

    // MARK: - refreshAfterEdit() (Task 5)

    @Test func refreshAfterEditRerendersCurrentCardWithoutAdvancing() async throws {
        final class State: @unchecked Sendable {
            var renderCallCount = 0
            var noteFields = "old front\u{1f}old back"
        }
        let state = State()
        let stubCard = QueuedReviewCard.preview(cardId: CardID(1), noteId: NoteID(100), ord: 0)
        let stubResult = QueuedCardsResult(
            cards: [stubCard], newCount: 1, learningCount: 0, reviewCount: 0
        )

        try await withDependencies {
            $0.notesService.getNote = { _ in
                NoteRecord(id: NoteID(100), guid: "g", mid: NotetypeID(200), mod: 0, flds: state.noteFields, sfld: "", csum: 0)
            }
            $0.schedulerService.getQueuedCards = { _ in stubResult }
            $0.cardRenderingService.renderCard = { _ in
                state.renderCallCount += 1
                return RenderedCard(
                    frontHTML: "<p>render-\(state.renderCallCount)</p>",
                    backHTML: "<p>back-\(state.renderCallCount)</p>",
                    cardCSS: ""
                )
            }
            $0.decksService.setCurrentDeck = { _ in }
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))
            session.start()
            try await pollUntil { !session.isAdvancing }

            let originalNoteId = session.currentNote?.id
            #expect(state.renderCallCount == 1)
            #expect(session.frontHTML.contains("render-1"))

            // Simulate field edit
            state.noteFields = "new front\u{1f}new back"
            await session.refreshAfterEdit()

            #expect(session.currentNote?.id == originalNoteId, "queue does not advance")
            #expect(state.renderCallCount == 2, "renderCard called again on refresh")
            #expect(session.frontHTML.contains("render-2"), "frontHTML reflects re-render")
        }
    }

    // MARK: - Off-main advance (start/answer run their backend chain off the main actor)

    /// answer() answers the current card, re-fetches the queue, and advances to
    /// the next card — all off the main actor — then updates stats on main.
    @Test func answerAdvancesToNextCardAndUpdatesStats() async throws {
        let card1 = QueuedReviewCard.preview(cardId: CardID(1), noteId: NoteID(100), ord: 0)
        let card2 = QueuedReviewCard.preview(cardId: CardID(2), noteId: NoteID(101), ord: 0)
        let note1 = NoteRecord(id: NoteID(100), guid: "g1", mid: NotetypeID(200), mod: 0, flds: "", sfld: "", csum: 0)
        let note2 = NoteRecord(id: NoteID(101), guid: "g2", mid: NotetypeID(200), mod: 0, flds: "", sfld: "", csum: 0)

        final class Box: @unchecked Sendable { var answered = false }
        let box = Box()

        try await withDependencies {
            $0.decksService.setCurrentDeck = { _ in }
            $0.schedulerService.getQueuedCards = { _ in
                // start() sees both cards; after answerReviewCard fires, only card2 remains.
                box.answered
                    ? QueuedCardsResult(cards: [card2], newCount: 1, learningCount: 0, reviewCount: 0)
                    : QueuedCardsResult(cards: [card1, card2], newCount: 2, learningCount: 0, reviewCount: 0)
            }
            $0.schedulerService.answerReviewCard = { _, _, _, _ in box.answered = true }
            $0.notesService.getNote = { id in id == NoteID(100) ? note1 : note2 }
            $0.cardRenderingService.renderCard = { _ in
                RenderedCard(frontHTML: "f", backHTML: "b", cardCSS: "")
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }
            #expect(s.currentNote == note1)

            s.answer(rating: .good)
            // answer() holds the card until the rating toast's 450ms minimum
            // display elapses, so the settle wait must outlast it.
            try await Task.sleep(for: .milliseconds(700))

            #expect(s.sessionStats.reviewed == 1)
            #expect(s.sessionStats.correct == 1, "Good counts as correct")
            #expect(s.canUndo)
            #expect(s.currentNote == note2, "should advance to the second card")
            #expect(!s.isAdvancing, "isAdvancing clears once the answer settles")
        }
    }

    /// isAdvancing flips true synchronously inside start() (before the internal
    /// Task runs) and clears once the off-main transition settles.
    @Test func isAdvancingSetSynchronouslyThenClears() async throws {
        let card = QueuedReviewCard.preview(cardId: CardID(1), noteId: NoteID(100), ord: 0)
        try await withDependencies {
            $0.decksService.setCurrentDeck = { _ in }
            $0.schedulerService.getQueuedCards = { _ in
                QueuedCardsResult(cards: [card], newCount: 1, learningCount: 0, reviewCount: 0)
            }
            $0.notesService.getNote = { _ in
                NoteRecord(id: NoteID(100), guid: "g", mid: NotetypeID(200), mod: 0, flds: "", sfld: "", csum: 0)
            }
            $0.cardRenderingService.renderCard = { _ in
                RenderedCard(frontHTML: "f", backHTML: "b", cardCSS: "")
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            #expect(s.isAdvancing, "start() sets isAdvancing synchronously before its Task runs")
            try await pollUntil { !s.isAdvancing }
            #expect(!s.isAdvancing, "isAdvancing clears after the transition settles")
            #expect(!s.isFinished, "a non-empty queue should not finish")
        }
    }

    // MARK: - start() failure

    /// A failed start used to set `isFinished`, landing the user on the
    /// congratulations surface — green checkmark, "You've reviewed 0 cards",
    /// success haptic — for a backend error. The two states are now distinct.
    @Test func startFailureReportsAnErrorInsteadOfFinishing() async throws {
        struct StartFailure: Error {}

        try await withDependencies {
            $0.decksService.setCurrentDeck = { _ in throw StartFailure() }
            $0.schedulerService.getQueuedCards = { _ in
                QueuedCardsResult(cards: [], newCount: 0, learningCount: 0, reviewCount: 0)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }

            #expect(s.startError != nil, "a failed start must surface the failure")
            #expect(!s.isFinished,
                    "isFinished drives the congratulations surface and its success haptic; a failure is not a finished deck")
        }
    }

    // MARK: - Re-queue: a card taken out of study
    //
    // Suspending, burying, forgetting, deleting the note and setting a due date
    // all report `shouldAdvance`. The session answers every one of them the same
    // way: throw the queue snapshot away, ask the deck what it yields now, and
    // take that card. See Documentation/adr/0001-live-session-total.md.

    /// Acceptance 1: the next card the deck yields appears, and the total is
    /// reduced by the card that left.
    @Test func requeueAdvancesToTheNextCardAndShrinksTheLiveTotal() async throws {
        let c1 = stubCard(1, note: 100)
        let c2 = stubCard(2, note: 101)
        let c3 = stubCard(3, note: 102)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { gather in
                gather == 1
                    ? stubQueue([c1, c2, c3], new: 3)
                    : stubQueue([c2, c3], new: 2)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }
            #expect(s.currentCardId == CardID(1))
            #expect(s.sessionTotal == 3)

            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing }

            #expect(gathers.count == 2, "the re-queue asks the deck what it yields now")
            #expect(s.currentCardId == CardID(2), "and shows the card the deck yields next")
            #expect(s.remainingCounts.newCount == 2)
            #expect(s.sessionTotal == 2, "4/12 → 4/11: the total is graded + live counts")
            #expect(s.studyNotice?.cardsTakenOutOfStudyCount == 1)
            #expect(!s.isFinished)
            #expect(s.requeueError == nil)
        }
    }

    /// A queue is re-gathered, never edited. The fresh gather can contain cards
    /// this session never held — a learning step came due, a sync landed cards —
    /// and the session has to follow what the deck actually says rather than
    /// splice its own array.
    @Test func requeueFollowsAFreshGatherInsteadOfSplicingItsOwnQueue() async throws {
        let c1 = stubCard(1, note: 100)
        let c2 = stubCard(2, note: 101)
        // Cards no part of this session ever queued.
        let c4 = stubCard(4, note: 103)
        let c5 = stubCard(5, note: 104)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { gather in
                gather == 1
                    ? stubQueue([c1, c2], new: 2)
                    : stubQueue([c2, c4, c5], new: 3)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }

            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing }

            #expect(s.remainingCounts.newCount == 3,
                    "splicing the old array would have left 1, not the deck's own 3")
            #expect(s.sessionTotal == 3, "so the total grows when the deck yields more")
            #expect(s.currentCardId == CardID(2))
            #expect(s.studyNotice?.cardsTakenOutOfStudyCount == 1,
                    "only c1 is provably gone; c2 is still queued")
        }
    }

    /// Acceptance 2: a note-level action takes every card of that note out in
    /// one step, and the caption names the real number (`ReviewStudyNotice` puts
    /// `cardsTakenOutOfStudyCount` into words; this is the number it must name).
    @Test func noteLevelTakeOutRemovesEveryCardOfTheNoteAtOnce() async throws {
        // One note, three cards — what `CardContextMenuModel.suspendNote` acts on.
        let c1 = stubCard(1, note: 100, ord: 0)
        let c2 = stubCard(2, note: 100, ord: 1)
        let c3 = stubCard(3, note: 100, ord: 2)
        // Another note's card, which the deck also stops yielding. The session
        // may not claim it: a card-menu action aims at the card on screen or at
        // its note, and this one belongs to neither.
        let other = stubCard(9, note: 200)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { gather in
                gather == 1 ? stubQueue([c1, c2, c3, other], new: 4) : stubQueue([], new: 0)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }

            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing }

            #expect(s.studyNotice?.cardsTakenOutOfStudyCount == 3,
                    "the note's three cards, not the four the deck stopped yielding")
            #expect(s.sessionTotal == 0)
        }
    }

    /// Acceptance 3 / R5: the last remaining card going out ends the session on
    /// the finished surface — not an error state — and nothing may be claimed
    /// reviewed.
    @Test func takingOutTheLastRemainingCardEndsTheSessionFinished() async throws {
        let c1 = stubCard(1, note: 100)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { gather in
                gather == 1 ? stubQueue([c1], new: 1) : stubQueue([], new: 0)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }

            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing }

            #expect(s.isFinished, "isFinished drives the congratulations surface and its success haptic")
            #expect(s.startError == nil && s.requeueError == nil,
                    "an empty deck after a take-out is not a failure")
            #expect(s.sessionStats.reviewed == 0, "the recap may not claim anything was reviewed")
            #expect(s.studyNotice?.cardsTakenOutOfStudyCount == 1)
        }
    }

    /// Acceptance 4 / R6: a card the deck hands straight back — "Forget Card"
    /// re-queues it as new — is never reported as gone, and it is a different
    /// card now, so it has to be prepared again rather than reused from the
    /// prefetch cache.
    @Test func aCardTheDeckHandsBackIsNotClaimedAsGoneAndIsPreparedAgain() async throws {
        let c1 = stubCard(1, note: 100)
        let gathers = Tally()
        let renders = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers, renders: renders) { _ in
                stubQueue([c1], new: 1)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { s.currentCardId != nil }
            #expect(renders.count >= 1)

            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing && renders.count >= 2 }

            #expect(s.studyNotice == nil, "the deck still yields it, so nothing left study")
            #expect(renders.count >= 2,
                    "the returned card is re-prepared, not reused: forget gave it new states")
            #expect(!s.isFinished)
            #expect(s.currentCardId == CardID(1))
            #expect(s.sessionStats.reviewed == 0)
        }
    }

    /// A re-queue is not a second way to start a session: with nothing on screen
    /// nothing was just taken out of study, and mid-transition it must not race
    /// the work already in flight.
    @Test func requeueWithoutACardOnScreenDoesNothing() async throws {
        let c1 = stubCard(1, note: 100)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { _ in stubQueue([c1], new: 1) }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))

            s.requeueAfterCardRemoval()
            #expect(gathers.count == 0, "no card on screen, nothing to take out")
            #expect(!s.isAdvancing, "and no transition gate left shut")
            #expect(!s.isFinished)
            #expect(s.currentCardId == nil)

            s.start()
            #expect(s.isAdvancing)
            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing }

            #expect(gathers.count == 1, "only start()'s gather ran")
            #expect(s.currentCardId == CardID(1))
        }
    }

    /// The card menu is not shut during a transition, so a take-out can land
    /// while an answer is in flight. Dropping it would leave the session's counts
    /// adrift until the next grade — the drift ADR-0001 says not to reintroduce —
    /// so it waits its turn instead.
    @Test func aTakeOutRequestedMidTransitionIsHonouredAfterIt() async throws {
        let c1 = stubCard(1, note: 100)
        let c2 = stubCard(2, note: 101)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { gather in
                switch gather {
                case 1: stubQueue([c1, c2], new: 2)
                case 2: stubQueue([c2], new: 1)      // the answer's gather
                default: stubQueue([], new: 0)       // the deferred re-queue's
                }
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }

            s.answer(rating: .good)
            #expect(s.isAdvancing, "the answer's transition is in flight")
            s.requeueAfterCardRemoval()

            try await pollUntil { !s.isAdvancing }

            #expect(gathers.count == 3, "the re-queue ran after the transition, not instead of it")
            #expect(s.studyNotice?.cardsTakenOutOfStudyCount == 1)
            #expect(s.isFinished, "and the deck yielded nothing, so the session is finished")
            #expect(s.sessionStats.reviewed == 1, "still only the one real grade")
        }
    }

    /// Acceptance 6: the hazard `answer()`'s own comment describes. A failed
    /// re-gather leaves the card in front of the user and says so; it never
    /// silently drops a card or claims one gone.
    @Test func failedRequeueLeavesTheCardOnScreenAndSaysSo() async throws {
        struct GatherFailure: Error {}
        let c1 = stubCard(1, note: 100)
        let c2 = stubCard(2, note: 101)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { gather in
                guard gather == 1 else { throw GatherFailure() }
                return stubQueue([c1, c2], new: 2)
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }

            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing }

            #expect(s.requeueError != nil, "a failed re-gather is surfaced, not swallowed")
            #expect(s.currentCardId == CardID(1), "the card stays in front of the user")
            #expect(s.studyNotice == nil, "nothing was re-gathered, so nothing may be claimed gone")
            #expect(s.remainingCounts.newCount == 2 && s.sessionTotal == 2,
                    "the counts stay where the engine last said they were")
            #expect(!s.isFinished)
        }
    }

    /// Acceptance 5 / R4: a re-queue changes no card and grades nothing. The
    /// graded counts are exactly what the answers produced, before and after.
    @Test func requeueGradesNothingAndLeavesTheGradedCountsAlone() async throws {
        let c1 = stubCard(1, note: 100)
        let c2 = stubCard(2, note: 101)
        let c3 = stubCard(3, note: 102)
        let gathers = Tally()

        try await withDependencies { deps in
            stubReviewClients(&deps, gathers: gathers) { gather in
                switch gather {
                case 1: stubQueue([c1, c2, c3], new: 3)
                case 2: stubQueue([c2, c3], new: 2)   // after the answer
                default: stubQueue([c3], new: 1)      // after the take-out
                }
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { !s.isAdvancing }

            s.answer(rating: .good)
            try await pollUntil { !s.isAdvancing }
            #expect(s.sessionStats.reviewed == 1)
            let graded = s.sessionStats

            s.requeueAfterCardRemoval()
            try await pollUntil { !s.isAdvancing }

            #expect(s.currentCardId == CardID(3))
            #expect(s.sessionStats == graded,
                    "a re-queue grades nothing: reviewed, correct and time are exactly what the answer produced")
            #expect(s.sessionTotal == 2,
                    "the one graded card plus the one card the deck still yields, nothing else")
            #expect(s.cardPosition == 2)
            #expect(s.studyNotice?.cardsTakenOutOfStudyCount == 1)
        }
    }

    // MARK: - Prefetch

    /// The card *after* the current one is rendered while the user reads, so
    /// the engine render is off the tap-to-next-card path.
    @Test func rendersTheFollowingCardBeforeTheUserAnswers() async throws {
        let card1 = QueuedReviewCard.preview(cardId: CardID(1), noteId: NoteID(100), ord: 0)
        let card2 = QueuedReviewCard.preview(cardId: CardID(2), noteId: NoteID(101), ord: 0)

        // renderCard is called from two concurrent detached tasks (the current
        // card's prepare and the prefetch), so the recorder locks.
        final class Rendered: @unchecked Sendable {
            private let lock = NSLock()
            private var ids: [CardID] = []
            func record(_ id: CardID) { lock.lock(); ids.append(id); lock.unlock() }
            var all: [CardID] { lock.lock(); defer { lock.unlock() }; return ids }
        }
        let rendered = Rendered()

        try await withDependencies {
            $0.decksService.setCurrentDeck = { _ in }
            $0.schedulerService.getQueuedCards = { _ in
                QueuedCardsResult(cards: [card1, card2], newCount: 2, learningCount: 0, reviewCount: 0)
            }
            $0.notesService.getNote = { id in
                NoteRecord(id: id, guid: "g", mid: NotetypeID(200), mod: 0, flds: "", sfld: "", csum: 0)
            }
            $0.cardRenderingService.renderCard = { id in
                rendered.record(id)
                return RenderedCard(frontHTML: "f", backHTML: "b", cardCSS: "")
            }
        } operation: {
            let s = ReviewSession(deckId: DeckID(1))
            s.start()
            try await pollUntil { rendered.all.contains(CardID(2)) }

            #expect(rendered.all.contains(CardID(1)), "the current card is rendered")
            #expect(rendered.all.contains(CardID(2)),
                    "the following card should be prefetched during the user's reading time")
            #expect(!s.isAdvancing, "prefetch must not hold the transition gate shut")
        }
    }
}

// MARK: - Stub helpers
//
// File scope on purpose: `ReviewSession` calls the mocked clients inside
// `Task.detached`, and a MainActor-isolated member of the suite is not callable
// from a `@Sendable` client closure.

/// A counter the mocked clients can share from off the main actor.
private final class Tally: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func bump() { lock.lock(); value += 1; lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
}

private func stubCard(_ id: Int64, note noteId: Int64, ord: Int32 = 0) -> QueuedReviewCard {
    QueuedReviewCard.preview(cardId: CardID(id), noteId: NoteID(noteId), ord: ord)
}

private func stubQueue(_ cards: [QueuedReviewCard], new: Int) -> QueuedCardsResult {
    QueuedCardsResult(cards: cards, newCount: new, learningCount: 0, reviewCount: 0)
}

/// Stubs everything a session needs to gather and prepare cards. `queue` decides
/// what each gather returns, counting from 1 (`start()`'s gather); `gathers`
/// records how many gathers actually ran.
private func stubReviewClients(
    _ values: inout DependencyValues,
    gathers: Tally,
    renders: Tally? = nil,
    queue: @escaping @Sendable (_ gather: Int) throws -> QueuedCardsResult
) {
    values.decksService.setCurrentDeck = { _ in }
    values.decksService.getCurrentDeck = { DeckInfo(id: DeckID(1), name: "Deck") }
    values.schedulerService.getQueuedCards = { _ in
        gathers.bump()
        return try queue(gathers.count)
    }
    values.schedulerService.answerReviewCard = { _, _, _, _ in }
    values.notesService.getNote = { id in
        NoteRecord(
            id: id, guid: "g\(id.rawValue)", mid: NotetypeID(200), mod: 0,
            flds: "f\u{1f}b", sfld: "f", csum: 0
        )
    }
    // `prepareCard` fetches the notetype only to label the render-mode chip.
    // These tests never look at that label, so the fetch declines rather than
    // tripping the unimplemented-closure warning.
    values.notetypesClient.get = { _ in throw NoNotetype() }
    values.cardRenderingService.renderCard = { _ in
        renders?.bump()
        return RenderedCard(frontHTML: "<p>front</p>", backHTML: "<p>back</p>", cardCSS: "")
    }
}

private struct NoNotetype: Error {}
