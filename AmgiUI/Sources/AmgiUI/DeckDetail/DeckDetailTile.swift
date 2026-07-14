public import SwiftUI
import AmgiTheme

/// Deck-detail counts tile. Three equal columns — New / Learning / Review —
/// each with a palette-themed numeral. All three columns always render
/// (three zeroes on an empty deck, never collapsed).
///
/// Built on `AmgiCard`. The heatmap agent (R03) places its chart below
/// this tile in the containing list — this component is self-contained.
public struct DeckDetailTile: View {
    let data: DeckDetailTileData

    @Environment(\.palette) private var palette

    public init(data: DeckDetailTileData) {
        self.data = data
    }

    public var body: some View {
        AmgiCard(
            background: .surfaceElevated,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.hero,
            contentInsets: EdgeInsets(top: 18, leading: 4, bottom: 18, trailing: 4)
        ) {
            HStack(spacing: 0) {
                countColumn(label: "New", value: data.newCount, color: palette.cardStateNew)
                columnDivider
                countColumn(label: "Learning", value: data.learnCount, color: palette.cardStateLearning)
                columnDivider
                countColumn(label: "Review", value: data.reviewCount, color: palette.cardStateReview)
            }
        }
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(palette.separator)
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }

    private func countColumn(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(palette.textSecondary)
            Text("\(value)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
private extension DeckDetailTileData {
    static let sampleHeavy = DeckDetailTileData(newCount: 20, learnCount: 93, reviewCount: 74)
    static let sampleZero  = DeckDetailTileData(newCount: 0,  learnCount: 0,  reviewCount: 0)
    static let sampleReviewOnly = DeckDetailTileData(newCount: 0, learnCount: 0, reviewCount: 24)
}

#Preview("Heavy counts") {
    DeckDetailTile(data: .sampleHeavy)
        .padding(16)
        .background(Color.gray.opacity(0.10))
        .environment(\.palette, .vividLight)
}

#Preview("Zero due — all three zeroes visible") {
    DeckDetailTile(data: .sampleZero)
        .padding(16)
        .background(Color.gray.opacity(0.10))
        .environment(\.palette, .vividLight)
}

#Preview("Review only (filtered deck)") {
    DeckDetailTile(data: .sampleReviewOnly)
        .padding(16)
        .background(Color.gray.opacity(0.10))
        .environment(\.palette, .vividLight)
}

#Preview("Dark mode") {
    DeckDetailTile(data: .sampleHeavy)
        .padding(16)
        .background(Color.black.opacity(0.85))
        .environment(\.palette, .vividDark)
}
#endif
