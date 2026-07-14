/// How a theme draws card elevation: soft drop shadows (default) or a
/// 1px hairline ring in the separator color (the Modern Minimal look —
/// mockup `box-shadow: 0 0 0 1px separator`).
public enum ElevationStyle: String, Codable, Sendable {
    case shadow
    case ring
}

/// How a theme renders deck tiles: leading emoji when the deck name has
/// one (default), or always a tinted monogram (first letters on the tint
/// at 11% opacity).
public enum DeckGlyphStyle: String, Codable, Sendable {
    case emoji
    case monogram
}
