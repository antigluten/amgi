import SwiftUI
import AnkiKit
import AnkiServices
import Dependencies
import Foundation

@Observable @MainActor
final class ReviewSession {
    let deckId: Int64

    @ObservationIgnored @Dependency(\.decksService) var decks
    @ObservationIgnored @Dependency(\.schedulerService) var scheduler
    @ObservationIgnored @Dependency(\.cardRenderingService) var cardRendering
    @ObservationIgnored @Dependency(\.collectionService) var collection

    private(set) var frontHTML: String = ""
    private(set) var backHTML: String = ""
    private(set) var showAnswer: Bool = false
    private(set) var sessionStats: SessionStats = .init()
    private(set) var remainingCounts: DeckCounts = .zero
    private(set) var isFinished: Bool = false
    private(set) var canUndo: Bool = false
    private(set) var nextIntervals: [Rating: String] = [:]
    private var reviewStartTime: Date = .now

    private var cardQueue: [QueuedReviewCard] = []
    private var currentQueuedCard: QueuedReviewCard?
    private var lastRating: Rating? = nil

    init(deckId: Int64) {
        self.deckId = deckId
    }

    func start() {
        do {
            try decks.setCurrentDeck(deckId)

            let result = try scheduler.getQueuedCards(200)
            cardQueue = result.cards
            remainingCounts = DeckCounts(
                newCount: result.newCount,
                learnCount: result.learningCount,
                reviewCount: result.reviewCount
            )
            print("[ReviewSession] Started with \(cardQueue.count) cards, counts: new=\(result.newCount) learn=\(result.learningCount) review=\(result.reviewCount)")
            advanceToNextCard()
        } catch {
            print("[ReviewSession] Start failed: \(error)")
            isFinished = true
        }
    }

    func revealAnswer() {
        showAnswer = true
    }

    func answer(rating: Rating) {
        guard let queued = currentQueuedCard else { return }

        let timeSpent = UInt32(Date.now.timeIntervalSince(reviewStartTime) * 1000)

        do {
            try scheduler.answerReviewCard(queued.card.id, rating, timeSpent, queued.states)

            sessionStats.reviewed += 1
            if rating != .again { sessionStats.correct += 1 }
            sessionStats.totalTimeMs += Int(timeSpent)
            lastRating = rating
            canUndo = true

            let result = try scheduler.getQueuedCards(200)
            cardQueue = result.cards
            remainingCounts = DeckCounts(
                newCount: result.newCount,
                learnCount: result.learningCount,
                reviewCount: result.reviewCount
            )
            advanceToNextCard()
        } catch {
            print("[ReviewSession] Answer failed: \(error)")
            if !cardQueue.isEmpty { cardQueue.removeFirst() }
            advanceToNextCard()
        }
    }

    func undo() {
        guard canUndo else { return }

        do {
            try collection.undoLast()
            canUndo = false

            // Roll back session stats
            sessionStats.reviewed -= 1
            if let last = lastRating, last != .again {
                sessionStats.correct -= 1
            }
            lastRating = nil

            // Re-fetch queue — Anki places the undone card at the front
            let result = try scheduler.getQueuedCards(200)
            cardQueue = result.cards
            remainingCounts = DeckCounts(
                newCount: result.newCount,
                learnCount: result.learningCount,
                reviewCount: result.reviewCount
            )
            advanceToNextCard()
        } catch {
            print("[ReviewSession] Undo failed: \(error)")
        }
    }

    private func advanceToNextCard() {
        guard let next = cardQueue.first else {
            isFinished = true
            currentQueuedCard = nil
            return
        }

        currentQueuedCard = next
        showAnswer = false
        reviewStartTime = .now
        nextIntervals = next.nextIntervals

        do {
            let rendered = try cardRendering.renderCard(next.card.id)
            frontHTML = rendered.frontHTML
            backHTML = rendered.backHTML
        } catch {
            print("[ReviewSession] Render failed for card \(next.card.id): \(error)")
            frontHTML = "<p>Error rendering card</p>"
            backHTML = "<p>Error rendering card</p>"
        }
    }
}
