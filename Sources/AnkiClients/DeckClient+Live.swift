import AnkiKit
import AnkiProto
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
            },
            rebuildFilteredDeck: { deckId in
                let count = try decks.rebuildFilteredDeck(deckId)
                logger.info("Rebuilt filtered deck \(deckId): \(count) cards")
                return count
            },
            emptyFilteredDeck: { deckId in
                try decks.emptyFilteredDeck(deckId)
                logger.info("Emptied filtered deck \(deckId)")
            },
            fetchDeckConfigContext: { deckId in
                try decks.fetchDeckConfigContext(deckId)
            },
            getDeckConfig: { deckId in
                try decks.getDeckConfig(deckId)
            },
            updateDeckConfig: { deckId, config, applyToChildren, fsrsEnabled, ignoreReviewLimit, applyAllParentLimits, fsrsHealthCheck in
                try decks.updateDeckConfig(deckId, config, applyToChildren, fsrsEnabled, ignoreReviewLimit, applyAllParentLimits, fsrsHealthCheck)
                logger.info("Updated deck config for deck=\(deckId), config=\(config.name), fsrs=\(fsrsEnabled)")
            },
            computeFsrsParams: { request in
                try decks.computeFsrsParams(request)
            },
            simulateFsrsReview: { request in
                try decks.simulateFsrsReview(request)
            },
            simulateFsrsWorkload: { request in
                try decks.simulateFsrsWorkload(request)
            },
            optimizeFsrsPresets: { deckId, config in
                try decks.optimizeFsrsPresets(deckId, config)
                logger.info("Optimized FSRS presets reachable from deck=\(deckId)")
            },
            selectDeckPreset: { deckId, config, applyToChildren in
                try decks.selectDeckPreset(deckId, config, applyToChildren)
                logger.info("Selected preset \(config.id) (\(config.name)) for deck=\(deckId)")
            },
            createDeckPreset: { deckId, baseConfig, name, applyToChildren in
                try decks.createDeckPreset(deckId, baseConfig, name, applyToChildren)
                logger.info("Created preset '\(name)' for deck=\(deckId)")
            },
            deleteDeckPreset: { deckId, removingConfigId, fallbackConfig, applyToChildren in
                try decks.deleteDeckPreset(deckId, removingConfigId, fallbackConfig, applyToChildren)
                logger.info("Deleted preset \(removingConfigId), deck=\(deckId) fell back to \(fallbackConfig.id)")
            }
        )
    }()
}
