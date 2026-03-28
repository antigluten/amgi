import AnkiKit
import AnkiBackend
import AnkiProto
import Foundation
public import Dependencies
import DependenciesMacros
import Logging

private let logger = Logger(label: "com.ankiapp.card.client")

extension CardClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            fetchDue: { deckId in
                // Set the current deck so the scheduler knows which deck to study
                var deckReq = Anki_Decks_DeckId()
                deckReq.did = deckId
                do {
                    try backend.callVoid(
                        service: AnkiBackend.Service.decks,
                        method: AnkiBackend.DecksMethod.setCurrentDeck,
                        request: deckReq
                    )
                    logger.info("Set current deck to \(deckId)")
                } catch {
                    logger.error("setCurrentDeck failed for deckId=\(deckId): \(error)")
                    throw error
                }

                // Verify the deck was actually set
                do {
                    let currentDeck: Anki_Decks_Deck = try backend.invoke(
                        service: AnkiBackend.Service.decks,
                        method: AnkiBackend.DecksMethod.getCurrentDeck,
                        request: Anki_Generic_Empty()
                    )
                    logger.info("Verified current deck: id=\(currentDeck.id), name=\(currentDeck.name)")
                } catch {
                    logger.warning("Could not verify current deck (non-fatal): \(error)")
                }

                var req = Anki_Scheduler_GetQueuedCardsRequest()
                req.fetchLimit = 200

                do {
                    let response: Anki_Scheduler_QueuedCards = try backend.invoke(
                        service: AnkiBackend.Service.scheduler,
                        method: AnkiBackend.SchedulerMethod.getQueuedCards,
                        request: req
                    )

                    logger.info("QueuedCards for deckId=\(deckId): \(response.cards.count) cards, new=\(response.newCount), learn=\(response.learningCount), review=\(response.reviewCount)")

                    let cards = response.cards.compactMap { queued -> CardRecord? in
                        guard queued.hasCard else {
                            logger.warning("Queued entry missing card data")
                            return nil
                        }
                        let c = queued.card
                        return CardRecord(
                            id: c.id, nid: c.noteID, did: c.deckID,
                            ord: Int32(c.templateIdx), mod: c.mtimeSecs,
                            usn: c.usn, type: Int16(c.ctype),
                            queue: Int16(c.queue), due: c.due,
                            ivl: Int32(c.interval), factor: Int32(c.easeFactor),
                            reps: Int32(c.reps), lapses: Int32(c.lapses),
                            left: Int32(c.remainingSteps), odue: c.originalDue,
                            odid: c.originalDeckID, flags: Int32(c.flags),
                            data: c.customData
                        )
                    }

                    if cards.isEmpty && (response.newCount > 0 || response.learningCount > 0 || response.reviewCount > 0) {
                        logger.error("Backend reports cards available (new=\(response.newCount), learn=\(response.learningCount), review=\(response.reviewCount)) but QueuedCards list is empty")
                    }

                    return cards
                } catch {
                    logger.error("fetchDue failed for deckId=\(deckId): \(error)")
                    throw error
                }
            },
            fetchByNote: { noteId in
                [] // Search-based; deferred to full implementation
            },
            save: { card in
                // Rust owns the DB; no direct writes needed
            },
            answer: { cardId, rating, timeSpent in
                var answer = Anki_Scheduler_CardAnswer()
                answer.cardID = cardId
                answer.rating = switch rating {
                case .again: .again
                case .hard: .hard
                case .good: .good
                case .easy: .easy
                }
                answer.answeredAtMillis = Int64(Date().timeIntervalSince1970 * 1000)
                answer.millisecondsTaken = UInt32(timeSpent)

                try backend.callVoid(
                    service: AnkiBackend.Service.scheduler,
                    method: AnkiBackend.SchedulerMethod.answerCard,
                    request: answer
                )
            },
            undo: { _ in },
            suspend: { cardId in },
            bury: { cardId in }
        )
    }()
}
