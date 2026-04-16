import AnkiKit
import AnkiServices
public import Dependencies
import DependenciesMacros
import Logging

private let logger = Logger(label: "com.ankiapp.deck.client")

extension DeckClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.decksService) var decks

        return Self(
            fetchAll: {
                let result = try decks.fetchAll()
                logger.info("fetchAll: \(result.count) decks")
                return result
            },
            fetchTree: {
                try decks.fetchTree()
            },
            countsForDeck: { deckId in
                let counts = try decks.countsForDeck(deckId)
                logger.info("Counts for deck \(deckId): new=\(counts.newCount), learn=\(counts.learnCount), review=\(counts.reviewCount)")
                return counts
            },
            create: { name in
                try decks.createDeck(name)
            },
            rename: { deckId, name in
                try decks.renameDeck(deckId, name)
            },
            delete: { deckId in
                try decks.removeDeck(deckId)
            }
        )
    }()
}
