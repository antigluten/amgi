import AnkiKit
import AnkiServices
public import Dependencies
import DependenciesMacros
import Logging

private let logger = Logger(label: "com.ankiapp.card.client")

extension CardClient: DependencyKey {
    public static let liveValue: Self = {
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
            bury: { _ in }
        )
    }()
}
