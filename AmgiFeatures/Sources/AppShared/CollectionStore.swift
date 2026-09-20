//
//  CollectionStore.swift
//  AppShared
//
//  Created by Vladimir Gusev on 11.07.2026.
//

import AnkiClients
public import AnkiKit
public import Dependencies
import Foundation
public import Observation

/// Single refresh authority for Collection reads — deck tree (+ its due
/// counts) in v1. Screens key `.task(id: store.generation)` so an
/// Invalidation re-runs their load; mutations hand their
/// `CollectionChanges` to `apply(_:)`; sync/import/review-end call
/// `invalidateAll()`.
@Observable
@MainActor
public final class CollectionStore {
    /// Bumped by every Invalidation that affects the deck tree.
    public private(set) var generation = 0

    /// Nonisolated so `CollectionStoreKey`'s lazy statics can be initialized
    /// from any thread. Only stored-property defaults run here.
    public nonisolated init() {}

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient

    @ObservationIgnored private var cachedTree: [DeckTreeNode]?
    @ObservationIgnored private var cachedGeneration = -1
    @ObservationIgnored private var inFlight: Task<[DeckTreeNode], any Error>?
    @ObservationIgnored private var inFlightGeneration = -1

    /// Read-through deck tree. Concurrent callers share one fetch; a
    /// generation bump makes both the cache and any in-flight fetch stale.
    public func tree() async throws -> [DeckTreeNode] {
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

    public func apply(_ changes: CollectionChanges) {
        guard changes.affectsDeckTree else { return }
        generation += 1
    }

    public func invalidateAll() {
        generation += 1
    }
}

private enum CollectionStoreKey: DependencyKey {
    // `static let` is initialized lazily by whichever thread touches it
    // first, which is not guaranteed to be the main thread. The old
    // `MainActor.assumeIsolated { ... }` would therefore trip "Incorrect
    // actor executor assumption" and abort the process if first resolved
    // from any Task.detached (there are 15+) or a background test.
    // CollectionStore has no explicit init, so a nonisolated one is safe and
    // removes the assumption entirely.
    static let liveValue = CollectionStore()
    static let testValue = CollectionStore()
}

extension DependencyValues {
    public var collectionStore: CollectionStore {
        get { self[CollectionStoreKey.self] }
        set { self[CollectionStoreKey.self] = newValue }
    }
}
