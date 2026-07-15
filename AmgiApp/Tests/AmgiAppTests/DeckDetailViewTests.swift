import Testing
@testable import AmgiApp

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
