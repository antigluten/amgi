import Testing
import SwiftUI
import UIKit
import Dependencies
import AnkiKit
import AnkiServices
@testable import AmgiApp

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
            try await Task.sleep(for: .milliseconds(50))
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
        session.updateCardChrome(color: UIColor.red, isDark: false)
        #expect(session.cardChromeColor == Color(uiColor: UIColor.red))
        #expect(!session.cardChromeIsDark)
        session.updateCardChrome(color: UIColor.black, isDark: true)
        #expect(session.cardChromeColor == Color(uiColor: UIColor.black))
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
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))
            session.start()
            try await Task.sleep(for: .milliseconds(50))
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
            try await Task.sleep(for: .milliseconds(50))
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
            try await Task.sleep(for: .milliseconds(50))

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
            session.updateCardChrome(color: UIColor.systemBlue, isDark: false)
            #expect(session.cardChromeColor == Color(uiColor: UIColor.systemBlue))
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
            try await Task.sleep(for: .milliseconds(50))

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
            try await Task.sleep(for: .milliseconds(50))
            #expect(s.currentNote == note1)

            s.answer(rating: .good)
            try await Task.sleep(for: .milliseconds(50))

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
            try await Task.sleep(for: .milliseconds(50))
            #expect(!s.isAdvancing, "isAdvancing clears after the transition settles")
            #expect(!s.isFinished, "a non-empty queue should not finish")
        }
    }
}
