//
//  EaseChart.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 30.03.2026.
//

public import SwiftUI
import Theme
import UI
import Charts
public import AnkiKit

public struct EaseChart: View {
    let eases: EaseBuckets

    public init(eases: EaseBuckets) {
        self.eases = eases
    }

    @Environment(\.palette) private var palette

    private var chartData: [(ease: Int, count: Int)] {
        eases.eases
            .map { (ease: Int($0.key), count: Int($0.value)) }
            .sorted(by: { $0.ease < $1.ease })
    }

    private var averageEase: String {
        guard eases.average > 0 else { return "---" }
        return String(format: "%.0f%%", eases.average / 10)
    }

    public var body: some View {
        AmgiCard(
            background: .surface,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Card Ease").amgiFont(.bodyEmphasis)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Avg: \(averageEase)")
                        .amgiFont(.captionBold)
                        .foregroundStyle(palette.textSecondary)
                }

                if chartData.isEmpty {
                    Text("No ease data").foregroundStyle(palette.textSecondary).frame(height: 180)
                } else {
                    Chart(chartData, id: \.ease) { item in
                        BarMark(
                            x: .value("Ease", item.ease),
                            y: .value("Cards", item.count)
                        )
                        .foregroundStyle(palette.accent.gradient)
                        .accessibilityLabel("\(item.ease / 10)% ease")
                        .accessibilityValue(ChartSpeech.count(item.count, "card"))
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine()
                            if let v = value.as(UInt32.self) {
                                AxisValueLabel("\(v / 10)%")
                            }
                        }
                    }
                    .frame(height: 180)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    EaseChart(eases: .sample)
        .padding()
}
#endif
