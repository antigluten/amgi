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
        // Counts are colour-coded (blue/orange/green); collapse into one
        // spoken label so the meaning isn't conveyed by colour alone.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

}

private extension DeckCountsView {
    var accessibilityLabel: String {
        guard counts.total > 0 else { return "No cards due" }
        var parts: [String] = []
        if counts.newCount > 0 { parts.append("\(counts.newCount) new") }
        if counts.learnCount > 0 { parts.append("\(counts.learnCount) learning") }
        if counts.reviewCount > 0 { parts.append("\(counts.reviewCount) to review") }
        return parts.joined(separator: ", ")
    }

    func countBadge(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DeckCountsView(counts: .sampleHeavy)
        DeckCountsView(counts: .sampleLight)
        DeckCountsView(counts: .zero)
    }
    .padding()
}
