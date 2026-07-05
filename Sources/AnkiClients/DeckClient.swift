public import AnkiKit
public import Dependencies
import DependenciesMacros

@DependencyClient
public struct DeckClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [DeckInfo]
    public var fetchTree: @Sendable () async throws -> [DeckTreeNode]
    public var countsForDeck: @Sendable (_ deckId: DeckID) async throws -> DeckCounts
    public var create: @Sendable (_ name: String) async throws -> DeckCreation
    public var rename: @Sendable (_ deckId: DeckID, _ name: String) async throws -> CollectionChanges
    public var delete: @Sendable (_ deckId: DeckID) async throws -> CollectionChanges
    public var rebuildFilteredDeck: @Sendable (_ deckId: DeckID) async throws -> Int
    public var emptyFilteredDeck: @Sendable (_ deckId: DeckID) async throws -> Void
    public var fetchDeckConfigContext: @Sendable (_ deckId: DeckID) async throws -> DeckConfigsForUpdate
    public var getDeckConfig: @Sendable (_ deckId: DeckID) async throws -> DeckConfig
    public var updateDeckConfig: @Sendable (
        _ deckId: DeckID,
        _ config: DeckConfig,
        _ applyToChildren: Bool,
        _ fsrsEnabled: Bool,
        _ newCardsIgnoreReviewLimit: Bool,
        _ applyAllParentLimits: Bool,
        _ fsrsHealthCheck: Bool
    ) async throws -> Void
    public var computeFsrsParams: @Sendable (_ request: FsrsOptimizeRequest) async throws -> FsrsOptimizeResult
    public var simulateFsrsReview: @Sendable (_ request: FsrsSimulationRequest) async throws -> FsrsReviewSimulation
    public var simulateFsrsWorkload: @Sendable (_ request: FsrsSimulationRequest) async throws -> FsrsWorkloadSimulation
    public var optimizeFsrsPresets: @Sendable (_ deckId: DeckID, _ config: DeckConfig) async throws -> Void
    public var selectDeckPreset: @Sendable (_ deckId: DeckID, _ config: DeckConfig, _ applyToChildren: Bool) async throws -> Void
    public var createDeckPreset: @Sendable (_ deckId: DeckID, _ baseConfig: DeckConfig, _ name: String, _ applyToChildren: Bool) async throws -> Void
    public var deleteDeckPreset: @Sendable (_ deckId: DeckID, _ removingConfigId: DeckConfigID, _ fallbackConfig: DeckConfig, _ applyToChildren: Bool) async throws -> Void
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
