//
//  AmgiRadius.swift
//  Theme
//
//  Created by Vladimir Gusev on 14.07.2026.
//

public import CoreGraphics

/// Central corner-radius tokens for the Minimal design language
/// (R23). Design-language values, shared by every theme — not palette
/// slots. A per-theme override can be added later without breaking
/// theme JSONs.
public enum AmgiRadius {
    private static let glass: Bool =
        if #available(iOS 26, macOS 26, watchOS 26, *) { true } else { false }

    /// Small chips, thumbnails, and cover art corners.
    public static let small: CGFloat = glass ? 12 : 8
    /// Inner tiles, list-card surfaces, insets. (was 14)
    public static let inset: CGFloat = glass ? 18 : 12
    /// Hero cards and top-level card chrome. (was 16–18)
    public static let hero: CGFloat = glass ? 22 : 14
    /// Buttons, chips, small glyph tiles. (was 14 for buttons)
    public static let control: CGFloat = glass ? 14 : 10
    /// R24's 56px floating tab pill. Reserved here so the token set is complete.
    public static let pill: CGFloat = 28
    /// R11's native review-card surface.
    public static let card: CGFloat = glass ? 26 : 24
}
