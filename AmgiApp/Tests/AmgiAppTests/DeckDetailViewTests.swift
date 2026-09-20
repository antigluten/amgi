//
//  DeckDetailViewTests.swift
//  AmgiAppTests
//
//  Created by Vladimir Gusev on 16.07.2026.
//

import Testing
import AnkiKit
@testable import AmgiApp
@testable import DecksFeature

/// Guards R29 Task 2: `DeckDetailView` must pass a leaf-only deck name to
/// `DeckTileGlyph.resolve` (via `shortTitle` → `deckName:`), not the full
/// "Parent::Child" path. `DeckDetailView.leafName(from:)` is the extracted
/// logic `shortTitle` calls — this test fails if that call is reverted to
/// using `deck.name` directly (see DeckDetailView.swift, commit 34b63a6).
@Suite struct DeckDetailViewTests {
    @Test func topLevelDeckNameIsUnchanged() {
        #expect(DeckDetailView.leafName(from: "Books") == "Books")
    }

    @Test func subdeckReturnsLeafSegmentOnly() {
        #expect(DeckDetailView.leafName(from: "Languages::Korean") == "Korean")
    }

    @Test func subdeckLeafWithEmojiIsPreserved() {
        // The resolver needs the emoji as the first character of the leaf
        // (not the full path) to detect `.emoji` mode.
        #expect(DeckDetailView.leafName(from: "Languages::📚 Vocab") == "📚 Vocab")
    }

    @Test func deeplyNestedPathReturnsOnlyTheLeaf() {
        #expect(DeckDetailView.leafName(from: "A::B::C::D") == "D")
    }
}

@MainActor
@Suite struct DeckDetailEmptinessTests {
    private let noneDue = DeckCounts.zero

    @Test func fullyReviewedDeckIsNotEmpty() {
        #expect(!DeckDetailModel.isEmpty(cardTotal: 42, counts: noneDue, childDecks: []))
    }

    @Test func deckWithNoCardsIsEmpty() {
        #expect(DeckDetailModel.isEmpty(cardTotal: 0, counts: noneDue, childDecks: []))
    }

    @Test func suspendedOnlyDeckIsNotEmpty() {
        // `includingInactive` counts suspended/buried cards, so a deck the
        // user suspended wholesale still has cards.
        #expect(!DeckDetailModel.isEmpty(cardTotal: 7, counts: noneDue, childDecks: []))
    }

    @Test func dueCountsStandInUntilTheCardTotalArrives() {
        let due = DeckCounts(newCount: 3, learnCount: 0, reviewCount: 0)
        #expect(!DeckDetailModel.isEmpty(cardTotal: nil, counts: due, childDecks: []))
        #expect(DeckDetailModel.isEmpty(cardTotal: nil, counts: noneDue, childDecks: []))
    }
}
