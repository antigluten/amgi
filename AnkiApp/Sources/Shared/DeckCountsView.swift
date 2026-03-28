import SwiftUI
import AnkiKit

struct DeckCountsView: View {
    let counts: DeckCounts

    var body: some View {
        HStack(spacing: 8) {
            if counts.newCount > 0 {
                countBadge(counts.newCount, color: .blue)
            }
            if counts.learnCount > 0 {
                countBadge(counts.learnCount, color: .orange)
            }
            if counts.reviewCount > 0 {
                countBadge(counts.reviewCount, color: .green)
            }
            if counts.total == 0 {
                Text("\u{2713}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func countBadge(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .monospacedDigit()
    }
}
