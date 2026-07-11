import AnkiClients
import AnkiKit
import Dependencies
import Foundation

/// Single refresh authority for Collection reads — deck tree (+ its due
/// counts) in v1. Screens key `.task(id: store.generation)` so an
/// Invalidation re-runs their load; mutations hand their
/// `CollectionChanges` to `apply(_:)`; sync/import/review-end call
/// `invalidateAll()`. See CONTEXT.md: CollectionStore, Invalidation.
@Observable
@MainActor
final class CollectionStore {
    /// Bumped by every Invalidation that affects the deck tree.
    private(set) var generation = 0

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient

    @ObservationIgnored private var cachedTree: [DeckTreeNode]?
    @ObservationIgnored private var cachedGeneration = -1
    @ObservationIgnored private var inFlight: Task<[DeckTreeNode], any Error>?
    @ObservationIgnored private var inFlightGeneration = -1

    /// Read-through deck tree. Concurrent callers share one fetch; a
    /// generation bump makes both the cache and any in-flight fetch stale.
    func tree() async throws -> [DeckTreeNode] {
        if let cachedTree, cachedGeneration == generation {
            return cachedTree
        }
        if let inFlight, inFlightGeneration == generation {
            return try await inFlight.value
        }
        let fetchGeneration = generation
        let client = deckClient
        let task = Task { try await client.fetchTree() }
        inFlight = task
        inFlightGeneration = fetchGeneration
        defer {
            if inFlightGeneration == fetchGeneration { inFlight = nil }
        }
        let tree = try await task.value
        if fetchGeneration == generation {
            cachedTree = tree
            cachedGeneration = fetchGeneration
        }
        return tree
    }

    func apply(_ changes: CollectionChanges) {
        guard changes.affectsDeckTree else { return }
        generation += 1
    }

    func invalidateAll() {
        generation += 1
    }
}

private enum CollectionStoreKey: DependencyKey {
    static let liveValue: CollectionStore = MainActor.assumeIsolated { CollectionStore() }
    static let testValue: CollectionStore = MainActor.assumeIsolated { CollectionStore() }
}

extension DependencyValues {
    var collectionStore: CollectionStore {
        get { self[CollectionStoreKey.self] }
        set { self[CollectionStoreKey.self] = newValue }
    }
}
