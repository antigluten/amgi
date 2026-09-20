//
//  DeckListLoadPerformanceTests.swift
//  DecksFeatureTests
//
//  Created by Vladimir Gusev on 02.09.2026.
//

import AppShared
import UI
import AnkiClients
import AnkiKit
import Dependencies
import XCTest
@testable import DecksFeature

/// Regression guard for the deck-list load — the action `AppSignpost` marks
/// as `DeckListLoad`, and the most expensive thing on the launch path.
///
/// Measured on a real 1,258-card / 38-deck / 14,777-revlog collection
/// (iPhone 17 Pro simulator, Release): `DeckListLoad` 192 ms, of which
/// `DeckListActivity` — the 365-day revlog assembly — was 45 ms and phase
/// one was 145 ms. A trace proves that today; this keeps it proven.
///
/// XCTest, not Swift Testing, deliberately: `measure(metrics:)` and the
/// `XCTClockMetric` / `XCTMemoryMetric` types have no Swift Testing
/// equivalent. The rest of the package's suites stay on Swift Testing.
///
/// These measure *assembly*, not the engine: the clients are stubbed, so a
/// regression here means the Swift-side mapping, state construction, or
/// heatmap folding got slower — not that the Rust backend did. Record a
/// baseline in Xcode (the diamond next to the test) for the numbers to be
/// enforced rather than merely reported.
final class DeckListLoadPerformanceTests: XCTestCase {

    // MARK: - Fixtures

    /// Shaped like the collection the profile was taken against: 7 top-level
    /// decks, 38 nodes in total, realistic due counts.
    private static func deckTree() -> [DeckTreeNode] {
        var nextID: Int64 = 1
        func node(_ name: String, parent: String?, children: [DeckTreeNode] = []) -> DeckTreeNode {
            defer { nextID += 1 }
            let full = parent.map { "\($0)::\(name)" } ?? name
            return DeckTreeNode(
                id: DeckID(nextID),
                name: name,
                fullName: full,
                counts: DeckCounts(newCount: 20, learnCount: 35, reviewCount: 72),
                isFiltered: false,
                children: children
            )
        }
        // 7 parents with 4 + 8 + 1 + 1 + 4 + 0 + 0 subdecks = 31 children.
        let subdeckCounts = [4, 8, 1, 1, 4, 0, 0]
        return zip(
            ["ComputerScience", "English", "Books", "Music", "Français", "Español", "Filtered"],
            subdeckCounts
        ).map { name, count in
            node(name, parent: nil, children: (0..<count).map { node("sub\($0)", parent: name) })
        }
    }

    /// A full year of review history, which is the window `load()` fetches.
    private static func graphs() -> GraphsSnapshot {
        var snapshot = GraphsSnapshot()
        var counts: [Int: ReviewCountsAndTimes.Reviews] = [:]
        for offset in -364...0 {
            counts[offset] = .init(learn: 12, relearn: 3, young: 40, mature: 25, filtered: 0)
        }
        snapshot.reviews = .init(count: counts, time: counts)
        return snapshot
    }

    @MainActor
    private static func makeModel() -> DeckListModel {
        let tree = deckTree()
        let snapshot = graphs()
        var deckClient = DeckClient()
        deckClient.fetchTree = { tree }
        return withDependencies {
            $0.deckClient = deckClient
            $0.statsClient = StatsClient { _, _ in snapshot }
        } operation: {
            // Built *inside* the scope, not while assembling DependencyValues:
            // `@Dependency` captures the ambient context when the property
            // wrapper initializes, so a store constructed in the `$0` closure
            // would capture the live deck client and fetch from the real
            // backend.
            let store = CollectionStore()
            return withDependencies {
                $0.collectionStore = store
            } operation: {
                DeckListModel()
            }
        }
    }

    // MARK: - Measurements

    /// Both phases of `DeckListLoad`: the tree fetch and row mapping, then
    /// the 365-day activity fold.
    func testDeckListLoadPerformance() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let loaded = expectation(description: "deck list loaded")
            Task { @MainActor in
                await Self.makeModel().load()
                loaded.fulfill()
            }
            // Pumps the main run loop, so the MainActor work above proceeds.
            wait(for: [loaded], timeout: 30)
        }
    }

    /// The pure fold on its own — no I/O, no actor hops, so a change here is
    /// unambiguously the algorithm rather than scheduling noise.
    func testHeatmapBuildPerformance() {
        let reviews = Self.graphs().reviews.count
        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<200 {
                _ = DeckListModel.buildHeatmap(reviews: reviews)
            }
        }
    }

    // MARK: - Correctness

    /// The measurement above is worthless if the fixture silently stops
    /// producing a loaded state — a thrown error would "measure" the failure
    /// path instead.
    @MainActor
    func testFixtureActuallyLoads() async {
        let model = Self.makeModel()
        await model.load()
        guard case .loaded(let rows, let hero, let heatmap) = model.state else {
            return XCTFail("expected .loaded, got \(model.state)")
        }
        XCTAssertEqual(rows.count, 7, "top-level rows")
        XCTAssertEqual(hero.deckCount, 7)
        XCTAssertEqual(heatmap?.counts.count, 365, "a full year of activity")
    }
}
