//
//  HourlyChart.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 27.03.2026.
//

public import SwiftUI
import Theme
import UI
import Charts
public import AnkiKit

public struct HourlyChart: View {
    let hours: HoursBuckets
    let period: StatsPeriod

    public init(hours: HoursBuckets, period: StatsPeriod) {
        self.hours = hours
        self.period = period
    }

    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var reviewChartHeight: CGFloat = 150
    @ScaledMetric(relativeTo: .caption) private var accuracyChartHeight: CGFloat = 100

    // At accessibility sizes even 3 labels touch on a 320pt phone, and .greedy does not add a gap.
    private var hourTicks: [Int] { typeSize.isAccessibilitySize ? [0, 12] : [0, 4, 8, 12, 16, 20] }

    private var cappedReviewHeight: CGFloat { min(reviewChartHeight, 225) }
    private var cappedAccuracyHeight: CGFloat { min(accuracyChartHeight, 150) }
    private var chartsHeight: CGFloat { cappedReviewHeight + AmgiSpacing.sm + cappedAccuracyHeight }

    private var hourData: [HoursBuckets.Hour] {
        switch period {
        case .day, .week, .month: hours.oneMonth
        case .threeMonths: hours.threeMonths
        case .year: hours.oneYear
        case .all: hours.allTime
        }
    }

    private struct HourEntry: Identifiable {
        let id: Int
        let hour: Int
        let total: Int
        let correctPct: Double
    }

    private var entries: [HourEntry] {
        guard hourData.count == 24 else {
            return (0..<24).map { HourEntry(id: $0, hour: $0, total: 0, correctPct: 0) }
        }
        return hourData.enumerated().map { index, hour in
            let pct = hour.total > 0 ? Double(hour.correct) / Double(hour.total) * 100 : 0
            return HourEntry(id: index, hour: index, total: Int(hour.total), correctPct: pct)
        }
    }

    public var body: some View {
        AmgiCard(
            background: .surface,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: AmgiSpacing.sm) {
                Text("Hourly Breakdown").amgiFont(.bodyEmphasis)

                if entries.allSatisfy({ $0.total == 0 }) {
                    Text("No review data").foregroundStyle(palette.textSecondary).frame(height: chartsHeight)
                } else {
                    Chart(entries) { entry in
                        BarMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Reviews", entry.total)
                        )
                        .foregroundStyle(palette.accent.gradient)
                        .accessibilityLabel(formatHour(entry.hour))
                        .accessibilityValue(ChartSpeech.count(entry.total, "review"))
                    }
                    .chartXAxis {
                        AxisMarks(values: hourTicks) { value in
                            AxisGridLine()
                            if let h = value.as(Int.self) {
                                AxisValueLabel(formatHour(h), collisionResolution: .greedy)
                            }
                        }
                    }
                    .chartXScale(domain: 0...23)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .frame(height: cappedReviewHeight)

                    Chart(entries) { entry in
                        LineMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Correct %", entry.correctPct)
                        )
                        .foregroundStyle(palette.positive)
                        .interpolationMethod(.catmullRom)
                        .accessibilityLabel(formatHour(entry.hour))
                        .accessibilityValue("\(ChartSpeech.percent(entry.correctPct)) correct")

                        AreaMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Correct %", entry.correctPct)
                        )
                        .foregroundStyle(palette.positive.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: hourTicks) { value in
                            AxisGridLine()
                            if let h = value.as(Int.self) {
                                AxisValueLabel(formatHour(h), collisionResolution: .greedy)
                            }
                        }
                    }
                    .chartXScale(domain: 0...23)
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("Correct %")
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .frame(height: cappedAccuracyHeight)
                }
            }
        }
    }
}

private extension HourlyChart {
    func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HourlyChart(hours: .sample, period: .month)
        .padding()
}
#endif
