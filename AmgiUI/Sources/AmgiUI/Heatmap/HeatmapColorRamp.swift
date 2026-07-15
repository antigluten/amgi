public import SwiftUI
public import AmgiTheme

/// Maps a review count to a `Color` using semantic palette tokens.
/// - Empty cell (count == 0): `palette.separator`
/// - Filled cells: interpolate from `palette.accentSoft` → `palette.accent`
///   across five intensity buckets.
///
/// Note: bucket 0 uses `palette.accent` at 0.20 opacity, which visually
/// approximates `palette.accentSoft` (defined as accent@0.15 in most themes)
/// without introducing a dependency on the exact accentSoft opacity value.
public enum HeatmapColorRamp {
    /// Opacity applied to `palette.accent` for each of the five filled buckets.
    /// Bucket 0 = faintest (very sparse day); bucket 4 = full accent.
    private static let filledOpacities: [Double] = [0.20, 0.38, 0.56, 0.76, 1.00]

    /// Color for a single heatmap cell.
    /// - Parameters:
    ///   - count: Total reviews for this day. 0 means no activity.
    ///   - maxCount: Normalisation ceiling from `HeatmapCardData.maxCount` (always ≥ 1).
    ///   - palette: Active theme palette from `@Environment(\.palette)`.
    public static func color(count: Int, maxCount: Int, palette: Palette) -> Color {
        guard count > 0 else { return palette.separator }
        let normalised = Double(count) / Double(max(maxCount, 1))
        let bucket = min(filledOpacities.count - 1, Int(normalised * Double(filledOpacities.count)))
        return palette.accent.opacity(filledOpacities[bucket])
    }

    /// Five swatches for the legend strip, faintest → darkest.
    public static func legendColors(palette: Palette) -> [Color] {
        filledOpacities.map { palette.accent.opacity($0) }
    }
}
