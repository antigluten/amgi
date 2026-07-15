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
