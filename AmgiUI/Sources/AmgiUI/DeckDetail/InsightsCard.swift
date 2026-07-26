public import SwiftUI
import AmgiTheme

/// Settings-style label/value rows in an inset-group card. Driven entirely
/// by `InsightsCardData` — trivially previewable.
///
/// Mirrors the `INSIGHTS` block in `design/deck.jsx`.
public struct InsightsCard: View {
    public let data: InsightsCardData

    @Environment(\.palette) private var palette

    public init(data: InsightsCardData) {
        self.data = data
    }

    public var body: some View {
        VStack(spacing: 0) {
            InsightRow(
                label: "Retention (30d)",
                value: data.retention30dPercent.map { "\($0)%" } ?? "—",
                tone: data.retention30dPercent != nil ? palette.positive : nil,
                isFirst: true
            )
            InsightRow(
                label: "Avg cards/day",
                value: data.avgCardsPerDay.map(String.init) ?? "—",
                tone: nil,
                isFirst: false
            )
            InsightRow(
                label: "Mature cards",
                value: "\(data.matureCards)",
                tone: nil,
                isFirst: false
            )
        }
        .background(palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.border, lineWidth: 0.5)
        )
    }
}

/// Single label/value row inside `InsightsCard`. Public so callers can
/// drop additional rows into the card from outside if a future variant
/// needs custom values — today the card uses three fixed rows.
public struct InsightRow: View {
    public let label: String
    public let value: String
    public let tone: Color?
    public let isFirst: Bool

    @Environment(\.palette) private var palette

    public init(label: String, value: String, tone: Color?, isFirst: Bool) {
        self.label = label
        self.value = value
        self.tone = tone
        self.isFirst = isFirst
    }

    public var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(tone ?? palette.textSecondary)
                .monospacedDigit()
        }
        .font(.body)
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(palette.border)
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Insights — populated") {
    InsightsCard(data: .init(retention30dPercent: 86, avgCardsPerDay: 59, matureCards: 200))
        .padding()
        .environment(\.palette, .vividLight)
}

#Preview("Insights — empty") {
    InsightsCard(data: .empty)
        .padding()
        .environment(\.palette, .vividLight)
}

#Preview("Insights — dark") {
    InsightsCard(data: .init(retention30dPercent: 86, avgCardsPerDay: 59, matureCards: 200))
        .padding()
        .background(Color.black)
        .environment(\.palette, .vividDark)
}
#endif
