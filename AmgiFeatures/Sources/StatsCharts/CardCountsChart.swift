//
//  CardCountsChart.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 30.03.2026.
//

public import SwiftUI
import Theme
import UI
import Charts
public import AnkiKit

public struct CardCountsChart: View {
    let cardCounts: CardCountsSeries

    public init(cardCounts: CardCountsSeries) {
        self.cardCounts = cardCounts
    }

    @Environment(\.palette) private var palette

    private var chartData: [(name: String, count: Int, color: Color)] {
        let c = cardCounts.excludingInactive
        return [
            (String(localized: "New", bundle: .module), Int(c.newCards), palette.cardStateNew),
            (String(localized: "Learning", bundle: .module), Int(c.learn), palette.cardStateLearning),
            (String(localized: "Relearning", bundle: .module), Int(c.relearn), palette.cardStateRelearn),
            (String(localized: "Young", bundle: .module), Int(c.young), palette.cardStateReview),
            (String(localized: "Mature", bundle: .module), Int(c.mature), palette.cardStateMature),
            (String(localized: "Suspended", bundle: .module), Int(c.suspended), palette.cardStateSuspended),
            (String(localized: "Buried", bundle: .module), Int(c.buried), palette.textTertiary),
        ].filter { $0.count > 0 }
    }

    private var total: Int { chartData.reduce(0) { $0 + $1.count } }

    public var body: some View {
        AmgiCard(
            background: .surface,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Card Counts", bundle: .module).amgiFont(.bodyEmphasis)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(total) total", bundle: .module).amgiFont(.caption).foregroundStyle(palette.textSecondary)
                }

                if chartData.isEmpty {
                    Text("No cards", bundle: .module).foregroundStyle(palette.textSecondary).frame(height: 180)
                } else {
                    Chart(chartData, id: \.name) { item in
                        SectorMark(
                            angle: .value(String(localized: "Count", bundle: .module), item.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
                        .foregroundStyle(item.color)
                        .accessibilityLabel(item.name)
                        .accessibilityValue(ChartSpeech.count(item.count, .card))
                    }
                    .frame(height: 200)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 4) {
                        ForEach(chartData, id: \.name) { item in
                            HStack(spacing: 4) {
                                Circle().fill(item.color).frame(width: 8, height: 8)
                                Text(item.name).amgiFont(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(item.count)").amgiFont(.captionBold).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CardCountsChart(cardCounts: .sample)
        .padding()
}
#endif
