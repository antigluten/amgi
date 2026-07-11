import Testing
import Foundation
import Dependencies
import AnkiKit
import AnkiClients
@testable import AmgiApp

/// Thread-safe fetch counter for asserting coalescing.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    var count: Int { lock.withLock { _count } }
    func bump() { lock.withLock { _count += 1 } }
}

private let sampleTree = [
    DeckTreeNode(
        id: DeckID(1), name: "Korean", fullName: "Korean",
        counts: DeckCounts(newCount: 1, learnCount: 2, reviewCount: 3),
        isFiltered: false, children: []
    )
]

@Suite("CollectionStore")
struct CollectionStoreTests {

    @Test @MainActor
    func concurrentReadersShareOneFetch() async throws {
        let counter = CallCounter()
        try await withDependencies {
            $0.deckClient.fetchTree = {
                counter.bump()
                try await Task.sleep(for: .milliseconds(50))
                return sampleTree
            }
        } operation: {
            let store = CollectionStore()
            async let a = store.tree()
            async let b = store.tree()
            let (treeA, treeB) = try await (a, b)
            #expect(treeA.count == 1)
            #expect(treeB.count == 1)
            #expect(counter.count == 1)
        }
    }

    @Test @MainActor
    func cachedTreeIsReusedUntilInvalidated() async throws {
        let counter = CallCounter()
        try await withDependencies {
            $0.deckClient.fetchTree = {
                counter.bump()
                return sampleTree
            }
        } operation: {
            let store = CollectionStore()
            _ = try await store.tree()
            _ = try await store.tree()
            #expect(counter.count == 1)

            store.apply(CollectionChanges(deck: true))
            _ = try await store.tree()
            #expect(counter.count == 2)
        }
    }

    @Test @MainActor
    func irrelevantChangesDoNotInvalidate() async throws {
        try await withDependencies {
            $0.deckClient.fetchTree = { sampleTree }
        } operation: {
            let store = CollectionStore()
            _ = try await store.tree()
            let before = store.generation
            store.apply(CollectionChanges(tag: true, notetype: true))
            #expect(store.generation == before)
        }
    }

    @Test @MainActor
    func invalidateAllBumpsGeneration() async throws {
        await withDependencies {
            $0.deckClient.fetchTree = { sampleTree }
        } operation: {
            let store = CollectionStore()
            let before = store.generation
            store.invalidateAll()
            #expect(store.generation == before + 1)
        }
    }
}
