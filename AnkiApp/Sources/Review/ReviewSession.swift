import SwiftUI
import AnkiKit
import AnkiClients
import AnkiBackend
import AnkiProto
import Dependencies
import Foundation
import SwiftProtobuf

@Observable @MainActor
final class ReviewSession {
    let deckId: Int64

    @ObservationIgnored @Dependency(\.deckClient) var deckClient
    @ObservationIgnored @Dependency(\.ankiBackend) var backend

    private(set) var frontHTML: String = ""
    private(set) var backHTML: String = ""
    private(set) var showAnswer: Bool = false
    private(set) var sessionStats: SessionStats = .init()
    private(set) var remainingCounts: DeckCounts = .zero
    private(set) var isFinished: Bool = false
    /// Next interval for each rating button (formatted string)
    private(set) var nextIntervals: [Rating: String] = [:]
    private var reviewStartTime: Date = .now

    /// The raw QueuedCard objects from the Rust backend — preserves scheduling states.
    private var cardQueue: [Anki_Scheduler_QueuedCards.QueuedCard] = []
    private var currentQueuedCard: Anki_Scheduler_QueuedCards.QueuedCard?

    init(deckId: Int64) {
        self.deckId = deckId
    }

    func start() {
        do {
            // Set current deck
            var deckReq = Anki_Decks_DeckId()
            deckReq.did = deckId
            try backend.callVoid(
                service: AnkiBackend.Service.decks,
                method: AnkiBackend.DecksMethod.setCurrentDeck,
                request: deckReq
            )

            // Get queued cards (preserving scheduling states)
            var req = Anki_Scheduler_GetQueuedCardsRequest()
            req.fetchLimit = 200
            let response: Anki_Scheduler_QueuedCards = try backend.invoke(
                service: AnkiBackend.Service.scheduler,
                method: AnkiBackend.SchedulerMethod.getQueuedCards,
                request: req
            )

            cardQueue = response.cards
            remainingCounts = DeckCounts(
                newCount: Int(response.newCount),
                learnCount: Int(response.learningCount),
                reviewCount: Int(response.reviewCount)
            )

            print("[ReviewSession] Started with \(cardQueue.count) cards, counts: new=\(remainingCounts.newCount) learn=\(remainingCounts.learnCount) review=\(remainingCounts.reviewCount)")
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
            var answer = Anki_Scheduler_CardAnswer()
            answer.cardID = queued.card.id

            // Pass the scheduling states from the QueuedCard
            answer.currentState = queued.states.current
            switch rating {
            case .again: answer.newState = queued.states.again
            case .hard: answer.newState = queued.states.hard
            case .good: answer.newState = queued.states.good
            case .easy: answer.newState = queued.states.easy
            }
            answer.rating = switch rating {
            case .again: .again
            case .hard: .hard
            case .good: .good
            case .easy: .easy
            }
            answer.answeredAtMillis = Int64(Date().timeIntervalSince1970 * 1000)
            answer.millisecondsTaken = timeSpent

            try backend.callVoid(
                service: AnkiBackend.Service.scheduler,
                method: AnkiBackend.SchedulerMethod.answerCard,
                request: answer
            )

            sessionStats.reviewed += 1
            if rating != .again { sessionStats.correct += 1 }
            sessionStats.totalTimeMs += Int(timeSpent)

            // Re-fetch queue (scheduler state changed)
            var req = Anki_Scheduler_GetQueuedCardsRequest()
            req.fetchLimit = 200
            let response: Anki_Scheduler_QueuedCards = try backend.invoke(
                service: AnkiBackend.Service.scheduler,
                method: AnkiBackend.SchedulerMethod.getQueuedCards,
                request: req
            )
            cardQueue = response.cards
            remainingCounts = DeckCounts(
                newCount: Int(response.newCount),
                learnCount: Int(response.learningCount),
                reviewCount: Int(response.reviewCount)
            )

            advanceToNextCard()
        } catch {
            print("[ReviewSession] Answer failed: \(error)")
            // Skip this card and move to next
            if !cardQueue.isEmpty { cardQueue.removeFirst() }
            advanceToNextCard()
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

        // Render the card using Rust backend
        do {
            var renderReq = Anki_CardRendering_RenderExistingCardRequest()
            renderReq.cardID = next.card.id
            renderReq.browser = false

            let rendered: Anki_CardRendering_RenderCardResponse = try backend.invoke(
                service: AnkiBackend.Service.cardRendering,
                method: AnkiBackend.CardRenderingMethod.renderExistingCard,
                request: renderReq
            )

            frontHTML = renderNodes(rendered.questionNodes)
            backHTML = renderNodes(rendered.answerNodes)

            if !rendered.css.isEmpty {
                let cssTag = "<style>\(rendered.css)</style>"
                frontHTML = cssTag + frontHTML
                backHTML = cssTag + backHTML
            }
        } catch {
            print("[ReviewSession] Render failed for card \(next.card.id): \(error)")
            frontHTML = "<p>Error rendering card</p>"
            backHTML = "<p>Error rendering card</p>"
        }

        // Extract next intervals from scheduling states
        let states = next.states
        nextIntervals = [
            .again: formatInterval(scheduledSecs(states.again)),
            .hard: formatInterval(scheduledSecs(states.hard)),
            .good: formatInterval(scheduledSecs(states.good)),
            .easy: formatInterval(scheduledSecs(states.easy)),
        ]
    }

    /// Extract the next interval from the scheduling state.
    /// Returns seconds for learning/relearning, days converted to seconds for review.
    private func scheduledSecs(_ state: Anki_Scheduler_SchedulingState) -> UInt32 {
        switch state.kind {
        case .normal(let n):
            return normalScheduledSecs(n)
        case .filtered:
            // Filtered decks — show 0 (can't predict)
            return 0
        case .none:
            return 0
        }
    }

    private func normalScheduledSecs(_ normal: Anki_Scheduler_SchedulingState.Normal) -> UInt32 {
        switch normal.kind {
        case .new: return 0
        case .learning(let s): return s.scheduledSecs
        case .review(let s): return s.scheduledDays * 86400 // days → seconds
        case .relearning(let s): return s.learning.scheduledSecs
        case .none: return 0
        }
    }

    private func formatInterval(_ secs: UInt32) -> String {
        if secs < 60 { return "\(secs)s" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 30 { return "\(days)d" }
        let months = days / 30
        if months < 12 { return "\(months)mo" }
        let years = Double(days) / 365.0
        return String(format: "%.1fy", years)
    }

    private func renderNodes(_ nodes: [Anki_CardRendering_RenderedTemplateNode]) -> String {
        nodes.map { node -> String in
            switch node.value {
            case .text(let text): return text
            case .replacement(let r): return r.currentText
            case .none: return ""
            }
        }.joined()
    }
}
