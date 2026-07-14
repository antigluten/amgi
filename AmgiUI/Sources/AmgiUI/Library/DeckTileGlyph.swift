import SwiftUI
import AmgiTheme

/// Computes the per-deck tile glyph + tint for the Library deck row.
/// Pure function over the deck name + palette. Internal — exposed only
/// to `@testable` consumers and `DeckListRowView`'s private subviews.
enum DeckTileGlyph {
    struct Resolved: Equatable, Sendable {
        let display: String
        let mode: Mode

        enum Mode: Equatable, Sendable {
            case emoji
            case letter(tint: Color)
            case monogram(tint: Color)
        }
    }

    static func resolve(deckName: String, palette: Palette) -> Resolved {
        let trimmed = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        if palette.deckGlyph == .monogram {
            // Strip a leading emoji (and following space) so "📚 Books" → "B".
            var name = trimmed
            if let first = name.first, isEmojiPresentation(first) {
                name = String(name.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            return Resolved(
                display: abbreviation(from: name),
                mode: .monogram(tint: tint(for: trimmed, palette: palette))
            )
        }
        if let firstChar = trimmed.first, isEmojiPresentation(firstChar) {
            return Resolved(display: String(firstChar), mode: .emoji)
        }
        return Resolved(
            display: abbreviation(from: trimmed),
            mode: .letter(tint: tint(for: trimmed, palette: palette))
        )
    }

    private static func isEmojiPresentation(_ c: Character) -> Bool {
        guard let first = c.unicodeScalars.first, first.properties.isEmoji else { return false }
        return first.properties.isEmojiPresentation
            || c.unicodeScalars.contains(where: { $0 == "\u{FE0F}" })
    }

    private static func abbreviation(from name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }.joined().uppercased()
        return letters.isEmpty ? "?" : String(letters.prefix(2))
    }

    private static func tint(for name: String, palette: Palette) -> Color {
        let palette6: [Color] = [
            palette.cardStateNew,
            palette.cardStateLearning,
            palette.cardStateReview,
            palette.cardStateMature,
            palette.cardStateRelearn,
            palette.cardStateSuspended
        ]
        var hash = 5381
        for byte in name.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return palette6[abs(hash) % palette6.count]
    }
}
