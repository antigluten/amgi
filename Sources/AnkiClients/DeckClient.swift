public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct DeckClient: Sendable {
    public var fetchAll: @Sendable () throws -> [DeckInfo]
    public var fetchTree: @Sendable () throws -> [DeckTreeNode]
    public var countsForDeck: @Sendable (_ deckId: DeckID) throws -> DeckCounts
    public var create: @Sendable (_ name: String) throws -> DeckCreation
    public var rename: @Sendable (_ deckId: DeckID, _ name: String) throws -> CollectionChanges
    public var delete: @Sendable (_ deckId: DeckID) throws -> CollectionChanges
    public var rebuildFilteredDeck: @Sendable (_ deckId: DeckID) throws -> Int
    public var emptyFilteredDeck: @Sendable (_ deckId: DeckID) throws -> Void
    public var fetchDeckConfigContext: @Sendable (_ deckId: DeckID) throws -> DeckConfigsForUpdate
    public var getDeckConfig: @Sendable (_ deckId: DeckID) throws -> DeckConfig
    public var updateDeckConfig: @Sendable (
        _ deckId: DeckID,
        _ config: DeckConfig,
        _ applyToChildren: Bool,
        _ fsrsEnabled: Bool,
        _ newCardsIgnoreReviewLimit: Bool,
        _ applyAllParentLimits: Bool,
        _ fsrsHealthCheck: Bool
    ) throws -> Void
    public var computeFsrsParams: @Sendable (_ request: FsrsOptimizeRequest) throws -> FsrsOptimizeResult
    public var simulateFsrsReview: @Sendable (_ request: FsrsSimulationRequest) throws -> FsrsReviewSimulation
    public var simulateFsrsWorkload: @Sendable (_ request: FsrsSimulationRequest) throws -> FsrsWorkloadSimulation
    public var optimizeFsrsPresets: @Sendable (_ deckId: DeckID, _ config: DeckConfig) throws -> Void
    public var selectDeckPreset: @Sendable (_ deckId: DeckID, _ config: DeckConfig, _ applyToChildren: Bool) throws -> Void
    public var createDeckPreset: @Sendable (_ deckId: DeckID, _ baseConfig: DeckConfig, _ name: String, _ applyToChildren: Bool) throws -> Void
    public var deleteDeckPreset: @Sendable (_ deckId: DeckID, _ removingConfigId: DeckConfigID, _ fallbackConfig: DeckConfig, _ applyToChildren: Bool) throws -> Void
}

extension DeckClient: TestDependencyKey {
    public static let testValue = DeckClient()
}

extension DependencyValues {
    public var deckClient: DeckClient {
        get { self[DeckClient.self] }
        set { self[DeckClient.self] = newValue }
    }
}
