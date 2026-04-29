import AnkiBackend
import AnkiKit
import AnkiProto
import AnkiServices
public import Dependencies
import DependenciesMacros
import Logging

private let logger = Logger(label: "com.ankiapp.card.client")

extension CardClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        @Dependency(\.schedulerService) var scheduler
        @Dependency(\.decksService) var decks

        return Self(
            fetchDue: { deckId in
                do {
                    try decks.setCurrentDeck(deckId)
                    logger.info("Set current deck to \(deckId)")
                } catch {
                    logger.error("setCurrentDeck failed for deckId=\(deckId): \(error)")
                    throw error
                }

                do {
                    let currentDeck = try decks.getCurrentDeck()
                    logger.info("Verified current deck: id=\(currentDeck.id), name=\(currentDeck.name)")
                } catch {
                    logger.warning("Could not verify current deck (non-fatal): \(error)")
                }

                do {
                    let result = try scheduler.getQueuedCards(200)
                    logger.info("QueuedCards for deckId=\(deckId): \(result.cards.count) cards")
                    return result.cards.map(\.card)
                } catch {
                    logger.error("fetchDue failed for deckId=\(deckId): \(error)")
                    throw error
                }
            },
            fetchByNote: { _ in [] },
            save: { _ in },
            answer: { cardId, rating, timeSpent in
                try scheduler.answerCard(cardId, rating, timeSpent)
            },
            undo: { _ in },
            suspend: { _ in },
            bury: { _ in },
            flag: { cardId, value in
                var req = Anki_Cards_SetFlagRequest()
                req.cardIds = [cardId]
                req.flag = value
                try backend.callVoid(
                    service: AnkiBackend.Service.cards,
                    method: AnkiBackend.CardsMethod.setFlag,
                    request: req
                )
            },
            resetToNew: { cardId in
                var req = Anki_Scheduler_ScheduleCardsAsNewRequest()
                req.cardIds = [cardId]
                req.log = true
                try backend.callVoid(
                    service: AnkiBackend.Service.scheduler,
                    method: AnkiBackend.SchedulerMethod.scheduleCardsAsNew,
                    request: req
                )
            },
            undoLast: {
                _ = try backend.call(
                    service: AnkiBackend.Service.collectionOps,
                    method: AnkiBackend.CollectionOpsMethod.undo
                )
            },
            getCardFlags: { cardId in
                var req = Anki_Cards_CardId()
                req.cid = cardId
                let card: Anki_Cards_Card = try backend.invoke(
                    service: AnkiBackend.Service.cards,
                    method: AnkiBackend.CardsMethod.getCard,
                    request: req
                )
                return card.flags & 0b111
            },
            hasUndoableAction: {
                let status: Anki_Collection_UndoStatus = try backend.invoke(
                    service: AnkiBackend.Service.collectionOps,
                    method: AnkiBackend.CollectionOpsMethod.getUndoStatus,
                    request: Anki_Generic_Empty()
                )
                return !status.undo.isEmpty
            },
            removeCards: { cardIds in
                var req = Anki_Cards_RemoveCardsRequest()
                req.cardIds = cardIds
                try backend.callVoid(
                    service: AnkiBackend.Service.cards,
                    method: AnkiBackend.CardsMethod.removeCards,
                    request: req
                )
                logger.info("Removed \(cardIds.count) cards")
            }
        )
    }()
}
