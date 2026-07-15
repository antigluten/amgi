import SwiftUI
import AmgiTheme
import AmgiUI
import Charts
import AnkiKit

struct CardCountsChart: View {
    let cardCounts: CardCountsSeries

    @Environment(\.palette) private var palette

    private var chartData: [(name: String, count: Int, color: Color)] {
        let c = cardCounts.excludingInactive
        return [
            ("New", Int(c.newCards), .cyan),
            ("Learning", Int(c.learn), .blue),
            ("Relearning", Int(c.relearn), .orange),
            ("Young", Int(c.young), .green),
            ("Mature", Int(c.mature), .purple),
            ("Suspended", Int(c.suspended), .gray),
            ("Buried", Int(c.buried), .brown),
        ].filter { $0.count > 0 }
    }

    private var total: Int { chartData.reduce(0) { $0 + $1.count } }

    var body: some View {
        AmgiCard(
            background: .surface,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Card Counts").amgiFont(.bodyEmphasis)
                    Spacer()
                    Text("\(total) total").font(.caption).foregroundStyle(.secondary)
                }

                if chartData.isEmpty {
                    Text("No cards").foregroundStyle(.secondary).frame(height: 180)
                } else {
                    Chart(chartData, id: \.name) { item in
                        SectorMark(
                            angle: .value("Count", item.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
                        .foregroundStyle(item.color)
                    }
                    .frame(height: 200)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 4) {
                        ForEach(chartData, id: \.name) { item in
                            HStack(spacing: 4) {
                                Circle().fill(item.color).frame(width: 8, height: 8)
                                Text(item.name).font(.caption)
                                Spacer()
                                Text("\(item.count)").font(.caption.monospacedDigit().weight(.medium))
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CardCountsChart(cardCounts: .sample)
        .padding()
}
