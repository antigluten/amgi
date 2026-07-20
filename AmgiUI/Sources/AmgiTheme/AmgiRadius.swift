public import CoreGraphics

/// Central corner-radius tokens for the Minimal design language
/// (R23). Design-language values, shared by every theme — not palette
/// slots. A per-theme override can be added later without breaking
/// theme JSONs.
public enum AmgiRadius {
    /// Small chips, thumbnails, and cover art corners.
    public static let small: CGFloat = 8
    /// Inner tiles, list-card surfaces, insets. (was 14)
    public static let inset: CGFloat = 12
    /// Hero cards and top-level card chrome. (was 16–18)
    public static let hero: CGFloat = 14
    /// Buttons, chips, small glyph tiles. (was 14 for buttons)
    public static let control: CGFloat = 10
    /// R24's 56px floating tab pill. Reserved here so the token set is complete.
    public static let pill: CGFloat = 28
    /// R11's native review-card surface.
    public static let card: CGFloat = 24
}
