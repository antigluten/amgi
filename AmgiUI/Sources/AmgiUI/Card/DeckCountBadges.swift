public import SwiftUI
import AmgiTheme

/// FSRS-colour three-column count badge strip: new (blue) / learning
/// (orange) / review (green). Only non-zero counts are shown. Used in
/// both the Library row and the Study "Up Next" list.
public struct DeckCountBadges: View {
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int

    @Environment(\.palette) private var palette

    public init(newCount: Int, learnCount: Int, reviewCount: Int) {
        self.newCount = newCount
        self.learnCount = learnCount
        self.reviewCount = reviewCount
    }

    public var body: some View {
        HStack(spacing: 10) {
            if newCount > 0 {
                badge(newCount, color: palette.cardStateNew)
            }
            if learnCount > 0 {
                badge(learnCount, color: palette.cardStateLearning)
            }
            if reviewCount > 0 {
                badge(reviewCount, color: palette.cardStateReview)
            }
        }
        .monospacedDigit()
    }

    private func badge(_ value: Int, color: Color) -> some View {
        Text("\(value)")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
    }
}
