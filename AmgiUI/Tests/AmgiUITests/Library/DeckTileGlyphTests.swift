import Testing
import SwiftUI
import AmgiTheme
@testable import AmgiUI

@Suite struct DeckTileGlyphTests {
    private let palette = Palette.vividLight

    @Test func leadingEmojiUsesEmojiMode() {
        let r = DeckTileGlyph.resolve(deckName: "🇰🇷 Korean", palette: palette)
        #expect(r.display == "🇰🇷")
        #expect(r.mode == .emoji)
    }

    @Test func simpleEmojiUsesEmojiMode() {
        let r = DeckTileGlyph.resolve(deckName: "📚 Books", palette: palette)
        #expect(r.display == "📚")
        #expect(r.mode == .emoji)
    }

    @Test func asciiNameUsesLetterMode() {
        let r = DeckTileGlyph.resolve(deckName: "English", palette: palette)
        #expect(r.display == "E")
        if case .letter = r.mode { /* ok */ } else {
            Issue.record("Expected .letter mode")
        }
    }

    @Test func twoWordNameTakesFirstTwoInitials() {
        let r = DeckTileGlyph.resolve(deckName: "Computer Science", palette: palette)
        #expect(r.display == "CS")
    }

    @Test func leadingDigitDoesNotCountAsEmoji() {
        // ASCII digits are emoji-capable in Unicode but render as text by default.
        let r = DeckTileGlyph.resolve(deckName: "3 Korean", palette: palette)
        if case .letter = r.mode { /* ok */ } else {
            Issue.record("Leading digit should fall through to letter mode")
        }
    }

    @Test func tintIsDeterministic() {
        let a = DeckTileGlyph.resolve(deckName: "English", palette: palette)
        let b = DeckTileGlyph.resolve(deckName: "English", palette: palette)
        #expect(a.mode == b.mode)
    }

    @Test func emptyNameReturnsQuestionMark() {
        let r = DeckTileGlyph.resolve(deckName: "", palette: palette)
        #expect(r.display == "?")
        if case .letter = r.mode { /* ok */ } else {
            Issue.record("Empty name should fall through to letter mode")
        }
    }

    @Test func whitespaceOnlyNameReturnsQuestionMark() {
        let r = DeckTileGlyph.resolve(deckName: "   ", palette: palette)
        #expect(r.display == "?")
    }

    @Test func monogramPaletteForcesMonogramForEmojiName() {
        let minimal = ThemeRegistry.shared.palette(id: .minimal, scheme: .light)
        let r = DeckTileGlyph.resolve(deckName: "📚 Books", palette: minimal)
        #expect(r.display == "B")
        if case .monogram = r.mode { /* ok */ } else {
            Issue.record("Monogram palette must skip the emoji branch")
        }
    }

    @Test func monogramPaletteUsesInitialsForPlainName() {
        let minimal = ThemeRegistry.shared.palette(id: .minimal, scheme: .light)
        let r = DeckTileGlyph.resolve(deckName: "Computer Science", palette: minimal)
        #expect(r.display == "CS")
        if case .monogram = r.mode { /* ok */ } else {
            Issue.record("Expected .monogram mode")
        }
    }

    @Test func emojiPaletteBehaviorUnchanged() {
        let r = DeckTileGlyph.resolve(deckName: "📚 Books", palette: Palette.vividLight)
        #expect(r.mode == .emoji)
    }

    // MARK: - Hierarchical paths ("Parent::Child") are NOT stripped

    // `resolve` documented as operating on a deck *name*, not a full
    // "::"-delimited path — these fixtures pin down that contract so a
    // future regression (a caller passing `DeckInfo.name`, which is the
    // full hierarchical path for a subdeck, instead of the leaf segment)
    // is caught here rather than slipping through because every existing
    // fixture above is a single-segment name. See R29 Task 2 follow-up:
    // DeckDetailView was passing `deck.name` (the full path) as
    // `deckName:`, which broke emoji detection, the letter abbreviation,
    // and the tint hash relative to what Library shows for the same deck.

    @Test func hierarchicalPathDefeatsEmojiDetection() {
        // A full path whose leaf starts with an emoji: the emoji is not
        // the first character of the *path*, so `.emoji` mode is missed.
        let r = DeckTileGlyph.resolve(deckName: "Parent::📚 Vocab", palette: palette)
        #expect(r.mode != .emoji)
    }

    @Test func leafOnlyNamePreservesEmojiDetection() {
        // The leaf segment alone (what callers must pass) round-trips
        // through `.emoji` mode correctly.
        let r = DeckTileGlyph.resolve(deckName: "📚 Vocab", palette: palette)
        #expect(r.display == "📚")
        #expect(r.mode == .emoji)
    }

    @Test func hierarchicalPathAndLeafDisagreeOnAbbreviationAndTint() {
        let path = DeckTileGlyph.resolve(deckName: "Parent::Child", palette: palette)
        let leaf = DeckTileGlyph.resolve(deckName: "Child", palette: palette)
        // Splitting the whole path on spaces yields a different (wrong)
        // abbreviation than abbreviating the leaf alone.
        #expect(path.display == "P")
        #expect(leaf.display == "C")
        #expect(path.display != leaf.display)
        // The tint hash runs over whatever string is passed in, so a full
        // path and its leaf land on different tiles.
        #expect(path.mode != leaf.mode)
    }

    @Test func deckDetailViewDataCarriesDeckNameNotAResolvedGlyph() {
        let data = DeckDetailViewData(
            title: "Books",
            subtitle: "",
            tone: .red,
            deckName: "📚 Books",
            tileCounts: DeckDetailTileData(newCount: 0, learnCount: 0, reviewCount: 0),
            isFiltered: false,
            isEmpty: true,
            subdecks: [],
            insights: .empty,
            isActionInFlight: false
        )
        // The tile resolves against the palette; the DTO must not pre-bake a glyph.
        #expect(data.deckName == "📚 Books")
    }
}
