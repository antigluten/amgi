import SwiftUI
import Charts
import AnkiKit

struct CardStateChart: View {
    let breakdown: CardStateBreakdown

    private var chartData: [(String, Int, Color)] {
        [
            ("New", breakdown.newCount, .blue),
            ("Learning", breakdown.learningCount, .orange),
            ("Review", breakdown.reviewCount, .green),
            ("Suspended", breakdown.suspendedCount, .gray),
        ].filter { $0.1 > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card States").amgiFont(.bodyEmphasis)

            if chartData.isEmpty {
                Text("No cards").foregroundStyle(.secondary).frame(height: 150)
            } else {
                Chart(chartData, id: \.0) { item in
                    SectorMark(angle: .value("Count", item.1), innerRadius: .ratio(0.5))
                        .foregroundStyle(item.2)
                }
                .frame(height: 180)

                HStack(spacing: 16) {
                    ForEach(chartData, id: \.0) { item in
                        HStack(spacing: 4) {
                            Circle().fill(item.2).frame(width: 8, height: 8)
                            Text("\(item.0): \(item.1)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .amgiCard()
    }
}
