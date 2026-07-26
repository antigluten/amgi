import Foundation

/// Pre-processed daily review counts for the activity heatmap.
/// Day offset 0 = today, -1 = yesterday, -N = N days ago.
/// Produced by the app-target container; `ActivityHeatmapCard` consumes it.
/// No `AnkiKit` import — callers convert `ReviewCountsAndTimes` before passing in.
public struct HeatmapCardData: Equatable, Hashable, Sendable {
    /// Day-offset (≤ 0) → total review count for that day.
    /// Days with zero reviews are absent (not stored as 0).
    public let counts: [Int: Int]

    /// The single highest daily count across all stored entries.
    /// Always ≥ 1 to avoid division-by-zero in the color ramp.
    public let maxCount: Int

    public init(counts: [Int: Int], maxCount: Int) {
        self.counts = counts
        self.maxCount = max(maxCount, 1)
    }

    public static let empty = HeatmapCardData(counts: [:], maxCount: 1)
}

#if DEBUG
public extension HeatmapCardData {
    /// Scattered activity with no streak — tests low-density rendering.
    static let sparse: HeatmapCardData = {
        var c: [Int: Int] = [:]
        for i in stride(from: 0, through: -179, by: -1) {
            if (i * 37) % 5 == 0 { c[i] = 1 + ((-i * 13) % 15) }
        }
        let mx = c.values.max() ?? 1
        return HeatmapCardData(counts: c, maxCount: mx)
    }()

    /// Heavy, near-daily activity — tests high-density rendering.
    static let dense: HeatmapCardData = {
        var c: [Int: Int] = [:]
        for i in (-364...0) {
            if (-i) % 7 != 3 { c[i] = 10 + ((-i * 13) % 25) }
        }
        let mx = c.values.max() ?? 1
        return HeatmapCardData(counts: c, maxCount: mx)
    }()

    /// Contiguous run for the last 42 days — tests streak-band rendering.
    static let streak: HeatmapCardData = {
        var c: [Int: Int] = [:]
        for i in (-41...0) { c[i] = 5 + ((-i * 7) % 20) }
        let mx = c.values.max() ?? 1
        return HeatmapCardData(counts: c, maxCount: mx)
    }()
}
#endif
