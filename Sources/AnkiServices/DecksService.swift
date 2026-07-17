import AnkiBackend
public import AnkiProto
public import AnkiKit
public import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DecksService: Sendable {
    public var fetchAll: @Sendable () throws -> [DeckInfo]
    public var fetchTree: @Sendable () throws -> [DeckTreeNode]
    public var countsForDeck: @Sendable (_ deckId: Int64) throws -> DeckCounts
    public var setCurrentDeck: @Sendable (_ deckId: Int64) throws -> Void
    public var getCurrentDeck: @Sendable () throws -> DeckInfo
    public var createDeck: @Sendable (_ name: String) throws -> Int64
    public var renameDeck: @Sendable (_ deckId: Int64, _ name: String) throws -> Void
    public var removeDeck: @Sendable (_ deckId: Int64) throws -> Void
    public var rebuildFilteredDeck: @Sendable (_ deckId: Int64) throws -> Int
    public var emptyFilteredDeck: @Sendable (_ deckId: Int64) throws -> Void
    public var fetchDeckConfigContext: @Sendable (_ deckId: Int64) throws -> Anki_DeckConfig_DeckConfigsForUpdate
    public var getDeckConfig: @Sendable (_ deckId: Int64) throws -> Anki_DeckConfig_DeckConfig
    public var updateDeckConfig: @Sendable (
        _ deckId: Int64,
        _ config: Anki_DeckConfig_DeckConfig,
        _ applyToChildren: Bool,
        _ fsrsEnabled: Bool,
        _ newCardsIgnoreReviewLimit: Bool,
        _ applyAllParentLimits: Bool,
        _ fsrsHealthCheck: Bool
    ) throws -> Void
    public var computeFsrsParams: @Sendable (_ request: Anki_Scheduler_ComputeFsrsParamsRequest) throws -> Anki_Scheduler_ComputeFsrsParamsResponse
    public var simulateFsrsReview: @Sendable (_ request: Anki_Scheduler_SimulateFsrsReviewRequest) throws -> Anki_Scheduler_SimulateFsrsReviewResponse
    public var simulateFsrsWorkload: @Sendable (_ request: Anki_Scheduler_SimulateFsrsReviewRequest) throws -> Anki_Scheduler_SimulateFsrsWorkloadResponse
    /// Re-computes parameters for every preset reachable from the deck, using
    /// the supplied baseline config as the deck's selected preset. Routes
    /// through `updateDeckConfigs` with mode `.computeAllParams`.
    public var optimizeFsrsPresets: @Sendable (_ deckId: Int64, _ config: Anki_DeckConfig_DeckConfig) throws -> Void
    /// Switch the deck to an existing preset. The supplied config keeps its
    /// id so the backend reuses the row instead of creating a new one.
    public var selectDeckPreset: @Sendable (_ deckId: Int64, _ config: Anki_DeckConfig_DeckConfig, _ applyToChildren: Bool) throws -> Void
    /// Create a new preset (id reset to 0) and select it for the deck.
    public var createDeckPreset: @Sendable (_ deckId: Int64, _ baseConfig: Anki_DeckConfig_DeckConfig, _ name: String, _ applyToChildren: Bool) throws -> Void
    /// Delete a preset and switch the deck to a fallback preset in one call.
    public var deleteDeckPreset: @Sendable (_ deckId: Int64, _ removingConfigId: Int64, _ fallbackConfig: Anki_DeckConfig_DeckConfig, _ applyToChildren: Bool) throws -> Void
}

extension DecksService: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            fetchAll: {
                var treeReq = Anki_Decks_DeckTreeRequest()
                treeReq.now = Int64(Date().timeIntervalSince1970)
                do {
                    let tree: Anki_Decks_DeckTreeNode = try backend.invoke(
                        service: AnkiBackend.Service.decks,
                        method: AnkiBackend.DecksMethod.getDeckTree,
                        request: treeReq
                    )
                    return flattenDeckTree(tree).sorted { $0.name < $1.name }
                } catch {
                    let namesReq = Anki_Decks_GetDeckNamesRequest()
                    let namesResp: Anki_Decks_DeckNames = try backend.invoke(
                        service: AnkiBackend.Service.decks,
                        method: AnkiBackend.DecksMethod.getDeckNames,
                        request: namesReq
                    )
                    return namesResp.entries
                        .map { DeckInfo(id: $0.id, name: $0.name, counts: .zero) }
                        .sorted { $0.name < $1.name }
                }
            },
            fetchTree: {
                var req = Anki_Decks_DeckTreeRequest()
                req.now = Int64(Date().timeIntervalSince1970)
                let tree: Anki_Decks_DeckTreeNode = try backend.invoke(
                    service: AnkiBackend.Service.decks,
                    method: AnkiBackend.DecksMethod.getDeckTree,
                    request: req
                )
                return tree.children.map { mapDeckTreeNode($0) }
            },
            countsForDeck: { deckId in
                var treeReq = Anki_Decks_DeckTreeRequest()
                treeReq.now = Int64(Date().timeIntervalSince1970)
                do {
                    let tree: Anki_Decks_DeckTreeNode = try backend.invoke(
                        service: AnkiBackend.Service.decks,
                        method: AnkiBackend.DecksMethod.getDeckTree,
                        request: treeReq
                    )
                    if let node = findNode(in: tree, deckId: deckId) {
                        return DeckCounts(
                            newCount: Int(node.newCount),
                            learnCount: Int(node.learnCount),
                            reviewCount: Int(node.reviewCount)
                        )
                    }
                } catch {}
                return .zero
            },
            setCurrentDeck: { deckId in
                var req = Anki_Decks_DeckId()
                req.did = deckId
                try backend.callVoid(
                    service: AnkiBackend.Service.decks,
                    method: AnkiBackend.DecksMethod.setCurrentDeck,
                    request: req
                )
            },
            getCurrentDeck: {
                let deck: Anki_Decks_Deck = try backend.invoke(
                    service: AnkiBackend.Service.decks,
                    method: AnkiBackend.DecksMethod.getCurrentDeck,
                    request: Anki_Generic_Empty()
                )
                return DeckInfo(id: deck.id, name: deck.name)
            },
            createDeck: { name in
                // Fetch a default Deck proto with all fields populated, then set name and add.
                var deck: Anki_Decks_Deck = try backend.invoke(
                    service: AnkiBackend.Service.decks,
                    method: AnkiBackend.DecksMethod.newDeck
                )
                deck.name = name
                let resp: Anki_Collection_OpChangesWithId = try backend.invoke(
                    service: AnkiBackend.Service.decks,
                    method: AnkiBackend.DecksMethod.addDeck,
                    request: deck
                )
                return resp.id
            },
            renameDeck: { deckId, name in
                var req = Anki_Decks_RenameDeckRequest()
                req.deckID = deckId
                req.newName = name
                try backend.callVoid(
                    service: AnkiBackend.Service.decks,
                    method: AnkiBackend.DecksMethod.renameDeck,
                    request: req
                )
            },
            removeDeck: { deckId in
                var req = Anki_Decks_DeckIds()
                req.dids = [deckId]
                try backend.callVoid(
                    service: AnkiBackend.Service.decks,
                    method: AnkiBackend.DecksMethod.removeDecks,
                    request: req
                )
            },
            rebuildFilteredDeck: { deckId in
                var req = Anki_Decks_DeckId()
                req.did = deckId
                let resp: Anki_Collection_OpChangesWithCount = try backend.invoke(
                    service: AnkiBackend.Service.scheduler,
                    method: AnkiBackend.SchedulerMethod.rebuildFilteredDeck,
                    request: req
                )
                return Int(resp.count)
            },
            emptyFilteredDeck: { deckId in
                var req = Anki_Decks_DeckId()
                req.did = deckId
                try backend.callVoid(
                    service: AnkiBackend.Service.scheduler,
                    method: AnkiBackend.SchedulerMethod.emptyFilteredDeck,
                    request: req
                )
            },
            fetchDeckConfigContext: { deckId in
                var req = Anki_Decks_DeckId()
                req.did = deckId
                return try backend.invoke(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.getDeckConfigsForUpdate,
                    request: req
                )
            },
            getDeckConfig: { deckId in
                var req = Anki_Decks_DeckId()
                req.did = deckId

                let context: Anki_DeckConfig_DeckConfigsForUpdate
                do {
                    context = try backend.invoke(
                        service: AnkiBackend.Service.deckConfig,
                        method: AnkiBackend.DeckConfigMethod.getDeckConfigsForUpdate,
                        request: req
                    )
                } catch {
                    // Fallback: read the deck and fetch its preset directly.
                    let deck: Anki_Decks_Deck = try backend.invoke(
                        service: AnkiBackend.Service.decks,
                        method: AnkiBackend.DecksMethod.getDeck,
                        request: req
                    )
                    guard case .normal(let normalDeck)? = deck.kind else {
                        throw error
                    }
                    var configReq = Anki_DeckConfig_DeckConfigId()
                    configReq.dcid = normalDeck.configID
                    return try backend.invoke(
                        service: AnkiBackend.Service.deckConfig,
                        method: AnkiBackend.DeckConfigMethod.getDeckConfig,
                        request: configReq
                    )
                }

                let currentConfigId = context.currentDeck.configID
                if currentConfigId != 0,
                   let matched = context.allConfig.first(where: { $0.config.id == currentConfigId })?.config {
                    return matched
                }
                if currentConfigId != 0 {
                    var configReq = Anki_DeckConfig_DeckConfigId()
                    configReq.dcid = currentConfigId
                    return try backend.invoke(
                        service: AnkiBackend.Service.deckConfig,
                        method: AnkiBackend.DeckConfigMethod.getDeckConfig,
                        request: configReq
                    )
                }
                if context.hasDefaults {
                    return context.defaults
                }
                throw BackendError(
                    kind: .invalidInput,
                    message: "Deck \(deckId) has no valid config id and no defaults available"
                )
            },
            updateDeckConfig: { deckId, config, applyToChildren, fsrsEnabled, newCardsIgnoreReviewLimit, applyAllParentLimits, fsrsHealthCheck in
                var ctxReq = Anki_Decks_DeckId()
                ctxReq.did = deckId
                let context: Anki_DeckConfig_DeckConfigsForUpdate = try backend.invoke(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.getDeckConfigsForUpdate,
                    request: ctxReq
                )

                var req = Anki_DeckConfig_UpdateDeckConfigsRequest()
                req.targetDeckID = deckId
                req.configs = [config]
                req.removedConfigIds = []
                req.mode = applyToChildren ? .applyToChildren : .normal
                req.cardStateCustomizer = context.cardStateCustomizer
                req.newCardsIgnoreReviewLimit = newCardsIgnoreReviewLimit
                req.applyAllParentLimits = applyAllParentLimits
                req.fsrsHealthCheck = fsrsHealthCheck
                req.fsrs = fsrsEnabled
                if context.currentDeck.hasLimits {
                    req.limits = context.currentDeck.limits
                }

                try backend.callVoid(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.updateDeckConfigs,
                    request: req
                )
            },
            computeFsrsParams: { request in
                try backend.invoke(
                    service: AnkiBackend.Service.scheduler,
                    method: AnkiBackend.SchedulerMethod.computeFsrsParams,
                    request: request
                )
            },
            simulateFsrsReview: { request in
                try backend.invoke(
                    service: AnkiBackend.Service.scheduler,
                    method: AnkiBackend.SchedulerMethod.simulateFsrsReview,
                    request: request
                )
            },
            simulateFsrsWorkload: { request in
                try backend.invoke(
                    service: AnkiBackend.Service.scheduler,
                    method: AnkiBackend.SchedulerMethod.simulateFsrsWorkload,
                    request: request
                )
            },
            optimizeFsrsPresets: { deckId, config in
                var ctxReq = Anki_Decks_DeckId()
                ctxReq.did = deckId
                let context: Anki_DeckConfig_DeckConfigsForUpdate = try backend.invoke(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.getDeckConfigsForUpdate,
                    request: ctxReq
                )
                var req = Anki_DeckConfig_UpdateDeckConfigsRequest()
                req.targetDeckID = deckId
                req.configs = [config]
                req.removedConfigIds = []
                req.mode = .computeAllParams
                req.cardStateCustomizer = context.cardStateCustomizer
                req.newCardsIgnoreReviewLimit = context.newCardsIgnoreReviewLimit
                req.applyAllParentLimits = context.applyAllParentLimits
                req.fsrsHealthCheck = context.fsrsHealthCheck
                req.fsrs = true
                if context.currentDeck.hasLimits {
                    req.limits = context.currentDeck.limits
                }
                try backend.callVoid(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.updateDeckConfigs,
                    request: req
                )
            },
            selectDeckPreset: { deckId, config, applyToChildren in
                let context = try fetchContext(backend: backend, deckId: deckId)
                let req = makeUpdateConfigsRequest(
                    deckId: deckId,
                    context: context,
                    configs: [config],
                    removed: [],
                    mode: applyToChildren ? .applyToChildren : .normal,
                    fsrs: context.fsrs
                )
                try backend.callVoid(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.updateDeckConfigs,
                    request: req
                )
            },
            createDeckPreset: { deckId, baseConfig, name, applyToChildren in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw BackendError(kind: .invalidInput, message: "Preset name can't be empty")
                }
                let context = try fetchContext(backend: backend, deckId: deckId)
                var newConfig = baseConfig
                newConfig.id = 0
                newConfig.name = trimmed
                let req = makeUpdateConfigsRequest(
                    deckId: deckId,
                    context: context,
                    configs: [newConfig],
                    removed: [],
                    mode: applyToChildren ? .applyToChildren : .normal,
                    fsrs: context.fsrs
                )
                try backend.callVoid(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.updateDeckConfigs,
                    request: req
                )
            },
            deleteDeckPreset: { deckId, removingConfigId, fallbackConfig, applyToChildren in
                guard removingConfigId != fallbackConfig.id else {
                    throw BackendError(kind: .invalidInput, message: "Fallback preset must differ from removed preset")
                }
                let context = try fetchContext(backend: backend, deckId: deckId)
                let req = makeUpdateConfigsRequest(
                    deckId: deckId,
                    context: context,
                    configs: [fallbackConfig],
                    removed: [removingConfigId],
                    mode: applyToChildren ? .applyToChildren : .normal,
                    fsrs: context.fsrs
                )
                try backend.callVoid(
                    service: AnkiBackend.Service.deckConfig,
                    method: AnkiBackend.DeckConfigMethod.updateDeckConfigs,
                    request: req
                )
            }
        )
    }()
}

private func fetchContext(backend: AnkiBackend, deckId: Int64) throws -> Anki_DeckConfig_DeckConfigsForUpdate {
    var req = Anki_Decks_DeckId()
    req.did = deckId
    return try backend.invoke(
        service: AnkiBackend.Service.deckConfig,
        method: AnkiBackend.DeckConfigMethod.getDeckConfigsForUpdate,
        request: req
    )
}

private func makeUpdateConfigsRequest(
    deckId: Int64,
    context: Anki_DeckConfig_DeckConfigsForUpdate,
    configs: [Anki_DeckConfig_DeckConfig],
    removed: [Int64],
    mode: Anki_DeckConfig_UpdateDeckConfigsMode,
    fsrs: Bool
) -> Anki_DeckConfig_UpdateDeckConfigsRequest {
    var req = Anki_DeckConfig_UpdateDeckConfigsRequest()
    req.targetDeckID = deckId
    req.configs = configs
    req.removedConfigIds = removed
    req.mode = mode
    req.cardStateCustomizer = context.cardStateCustomizer
    req.newCardsIgnoreReviewLimit = context.newCardsIgnoreReviewLimit
    req.applyAllParentLimits = context.applyAllParentLimits
    req.fsrsHealthCheck = context.fsrsHealthCheck
    req.fsrs = fsrs
    if context.currentDeck.hasLimits {
        req.limits = context.currentDeck.limits
    }
    return req
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

// MARK: - Helpers

private func flattenDeckTree(_ node: Anki_Decks_DeckTreeNode, parentPath: String = "") -> [DeckInfo] {
    var result: [DeckInfo] = []
    for child in node.children {
        let fullPath = parentPath.isEmpty ? child.name : "\(parentPath)::\(child.name)"
        result.append(DeckInfo(
            id: child.deckID,
            name: fullPath,
            counts: DeckCounts(
                newCount: Int(child.newCount),
                learnCount: Int(child.learnCount),
                reviewCount: Int(child.reviewCount)
            ),
            isFiltered: child.filtered
        ))
        result.append(contentsOf: flattenDeckTree(child, parentPath: fullPath))
    }
    return result
}

private func findNode(in node: Anki_Decks_DeckTreeNode, deckId: Int64) -> Anki_Decks_DeckTreeNode? {
    if node.deckID == deckId { return node }
    for child in node.children {
        if let found = findNode(in: child, deckId: deckId) { return found }
    }
    return nil
}

private func mapDeckTreeNode(_ node: Anki_Decks_DeckTreeNode, parentPath: String = "") -> DeckTreeNode {
    let fullPath = parentPath.isEmpty ? node.name : "\(parentPath)::\(node.name)"
    return DeckTreeNode(
        id: node.deckID,
        name: node.name,
        fullName: fullPath,
        counts: DeckCounts(
            newCount: Int(node.newCount),
            learnCount: Int(node.learnCount),
            reviewCount: Int(node.reviewCount)
        ),
        isFiltered: node.filtered,
        children: node.children.map { mapDeckTreeNode($0, parentPath: fullPath) }
    )
}

