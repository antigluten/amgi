import AnkiBackend
import AnkiProtoBridge
public import AnkiKit
public import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DecksService: Sendable {
    public var fetchAll: @Sendable () throws -> [DeckInfo]
    public var fetchTree: @Sendable () throws -> [DeckTreeNode]
    public var countsForDeck: @Sendable (_ deckId: DeckID) throws -> DeckCounts
    public var setCurrentDeck: @Sendable (_ deckId: DeckID) throws -> Void
    public var getCurrentDeck: @Sendable () throws -> DeckInfo
    public var createDeck: @Sendable (_ name: String) throws -> DeckID
    public var renameDeck: @Sendable (_ deckId: DeckID, _ name: String) throws -> Void
    public var removeDeck: @Sendable (_ deckId: DeckID) throws -> Void
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
    /// Re-computes parameters for every preset reachable from the deck, using
    /// the supplied baseline config as the deck's selected preset. Routes
    /// through `updateDeckConfigs` with mode `.computeAllParams`.
    public var optimizeFsrsPresets: @Sendable (_ deckId: DeckID, _ config: DeckConfig) throws -> Void
    /// Switch the deck to an existing preset. The supplied config keeps its
    /// id so the backend reuses the row instead of creating a new one.
    public var selectDeckPreset: @Sendable (_ deckId: DeckID, _ config: DeckConfig, _ applyToChildren: Bool) throws -> Void
    /// Create a new preset (id reset to 0) and select it for the deck.
    public var createDeckPreset: @Sendable (_ deckId: DeckID, _ baseConfig: DeckConfig, _ name: String, _ applyToChildren: Bool) throws -> Void
    /// Delete a preset and switch the deck to a fallback preset in one call.
    public var deleteDeckPreset: @Sendable (_ deckId: DeckID, _ removingConfigId: DeckConfigID, _ fallbackConfig: DeckConfig, _ applyToChildren: Bool) throws -> Void
}

extension DecksService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            fetchAll: {
                do {
                    return try backend.invoke(.deckTree()).sortedByName
                } catch {
                    return try backend.invoke(.deckNames).sortedByName
                }
            },
            fetchTree: {
                try backend.invoke(.deckTree())
            },
            countsForDeck: { deckId in
                let counts = try? backend.invoke(.deckCounts(for: deckId))
                return counts.flatMap { $0 } ?? .zero
            },
            setCurrentDeck: { deckId in
                try backend.invoke(.setCurrentDeck(deckId: deckId))
            },
            getCurrentDeck: {
                try backend.invoke(.getCurrentDeck)
            },
            createDeck: { name in
                let template = try backend.invoke(.newDeck)
                return try backend.invoke(.addDeck(template: template, name: name))
            },
            renameDeck: { deckId, name in
                try backend.invoke(.renameDeck(deckId: deckId, newName: name))
            },
            removeDeck: { deckId in
                try backend.invoke(.removeDecks(deckIds: [deckId]))
            },
            rebuildFilteredDeck: { deckId in
                try backend.invoke(.rebuildFilteredDeck(deckId: deckId))
            },
            emptyFilteredDeck: { deckId in
                try backend.invoke(.emptyFilteredDeck(deckId: deckId))
            },
            fetchDeckConfigContext: { deckId in
                try backend.invoke(.deckConfigsForUpdate(deckId: deckId))
            },
            getDeckConfig: { deckId in
                let context = try backend.invoke(.deckConfigsForUpdate(deckId: deckId))
                let currentConfigId = context.currentDeck?.configID ?? DeckConfigID(0)
                if currentConfigId.rawValue != 0,
                   let matched = context.allConfig.first(where: { $0.config.id == currentConfigId })?.config {
                    return matched
                }
                if currentConfigId.rawValue != 0 {
                    return try backend.invoke(.deckConfig(for: currentConfigId))
                }
                if let defaults = context.defaults {
                    return defaults
                }
                throw BackendError(
                    kind: .invalidInput,
                    message: "Deck \(deckId.rawValue) has no valid config id and no defaults available"
                )
            },
            updateDeckConfig: { deckId, config, applyToChildren, fsrsEnabled, newCardsIgnoreReviewLimit, applyAllParentLimits, fsrsHealthCheck in
                let context = try backend.invoke(.deckConfigsForUpdate(deckId: deckId))
                let request = UpdateDeckConfigsRequest(
                    targetDeckID: deckId,
                    configs: [config],
                    mode: applyToChildren ? .applyToChildren : .normal,
                    cardStateCustomizer: context.cardStateCustomizer,
                    limits: context.currentDeck?.limits,
                    newCardsIgnoreReviewLimit: newCardsIgnoreReviewLimit,
                    fsrs: fsrsEnabled,
                    applyAllParentLimits: applyAllParentLimits,
                    fsrsHealthCheck: fsrsHealthCheck
                )
                try backend.invoke(.updateDeckConfigs(request))
            },
            computeFsrsParams: { request in
                try backend.invoke(.computeFsrsParams(request))
            },
            simulateFsrsReview: { request in
                try backend.invoke(.simulateFsrsReview(request))
            },
            simulateFsrsWorkload: { request in
                try backend.invoke(.simulateFsrsWorkload(request))
            },
            optimizeFsrsPresets: { deckId, config in
                let context = try backend.invoke(.deckConfigsForUpdate(deckId: deckId))
                let request = makeUpdateRequest(
                    deckId: deckId,
                    context: context,
                    configs: [config],
                    removed: [],
                    mode: .computeAllParams,
                    fsrs: true
                )
                try backend.invoke(.updateDeckConfigs(request))
            },
            selectDeckPreset: { deckId, config, applyToChildren in
                let context = try backend.invoke(.deckConfigsForUpdate(deckId: deckId))
                let request = makeUpdateRequest(
                    deckId: deckId,
                    context: context,
                    configs: [config],
                    removed: [],
                    mode: applyToChildren ? .applyToChildren : .normal,
                    fsrs: context.fsrs
                )
                try backend.invoke(.updateDeckConfigs(request))
            },
            createDeckPreset: { deckId, baseConfig, name, applyToChildren in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw BackendError(kind: .invalidInput, message: "Preset name can't be empty")
                }
                let context = try backend.invoke(.deckConfigsForUpdate(deckId: deckId))
                var newConfig = baseConfig
                newConfig.id = DeckConfigID(0)
                newConfig.name = trimmed
                let request = makeUpdateRequest(
                    deckId: deckId,
                    context: context,
                    configs: [newConfig],
                    removed: [],
                    mode: applyToChildren ? .applyToChildren : .normal,
                    fsrs: context.fsrs
                )
                try backend.invoke(.updateDeckConfigs(request))
            },
            deleteDeckPreset: { deckId, removingConfigId, fallbackConfig, applyToChildren in
                guard removingConfigId != fallbackConfig.id else {
                    throw BackendError(kind: .invalidInput, message: "Fallback preset must differ from removed preset")
                }
                let context = try backend.invoke(.deckConfigsForUpdate(deckId: deckId))
                let request = makeUpdateRequest(
                    deckId: deckId,
                    context: context,
                    configs: [fallbackConfig],
                    removed: [removingConfigId],
                    mode: applyToChildren ? .applyToChildren : .normal,
                    fsrs: context.fsrs
                )
                try backend.invoke(.updateDeckConfigs(request))
            }
        )
    }()
}

private func makeUpdateRequest(
    deckId: DeckID,
    context: DeckConfigsForUpdate,
    configs: [DeckConfig],
    removed: [DeckConfigID],
    mode: UpdateDeckConfigsMode,
    fsrs: Bool
) -> UpdateDeckConfigsRequest {
    UpdateDeckConfigsRequest(
        targetDeckID: deckId,
        configs: configs,
        removedConfigIds: removed,
        mode: mode,
        cardStateCustomizer: context.cardStateCustomizer,
        limits: context.currentDeck?.limits,
        newCardsIgnoreReviewLimit: context.newCardsIgnoreReviewLimit,
        fsrs: fsrs,
        applyAllParentLimits: context.applyAllParentLimits,
        fsrsHealthCheck: context.fsrsHealthCheck
    )
}

extension DecksService: TestDependencyKey {
    public static let testValue = DecksService()
}

extension DependencyValues {
    public var decksService: DecksService {
        get { self[DecksService.self] }
        set { self[DecksService.self] = newValue }
    }
}
