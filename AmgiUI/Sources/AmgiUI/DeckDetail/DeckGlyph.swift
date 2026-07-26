import Foundation

/// Picks the glyph (emoji / flag) to render inside the deck hero tile.
///
/// Strategy:
/// 1. If the deck name's leading extended-grapheme cluster is an emoji,
///    use it verbatim. That covers `🇰🇷 한국어`, `📚 Vocab`, etc.
/// 2. Otherwise fall back to the `📚` default.
///
/// Pure function — no theme/palette dependency. Lives in AmgiUI so views
/// can compose it without bouncing through AnkiKit.
public enum DeckGlyph {
    public static func from(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip any "::" deck-hierarchy prefix — only the leaf matters.
        let leaf = String(trimmed.split(separator: "::", omittingEmptySubsequences: true).last ?? Substring(trimmed))
        guard let first = leaf.first, isEmoji(first) else {
            return "📚"
        }
        return String(first)
    }

    private static func isEmoji(_ char: Character) -> Bool {
        // A grapheme cluster is treated as emoji when any of its unicode
        // scalars is an emoji-presentation scalar, OR when the cluster has
        // multiple scalars (regional-indicator flags, ZWJ sequences).
        if char.unicodeScalars.count > 1 {
            return char.unicodeScalars.contains { $0.properties.isEmoji }
        }
        guard let scalar = char.unicodeScalars.first else { return false }
        return scalar.properties.isEmojiPresentation
            || (scalar.properties.isEmoji && scalar.value > 0x238C)
    }
}
