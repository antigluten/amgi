//
//  FutureDueChart.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 30.03.2026.
//

public import SwiftUI
import Theme
import UI
import Charts
public import AnkiKit

public struct FutureDueChart: View {
    let futureDue: FutureDueSeries
    let period: StatsPeriod

    public init(futureDue: FutureDueSeries, period: StatsPeriod) {
        self.futureDue = futureDue
        self.period = period
    }

    @Environment(\.palette) private var palette
    @State private var includeBacklog = false
    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 180

    private var cappedChartHeight: CGFloat { min(chartHeight, 270) }

    private var filteredData: [(day: Int, count: Int)] {
        let maxDay = period.days
        return futureDue.futureDue
            .compactMap { (dayOffset, count) -> (day: Int, count: Int)? in
                let day = Int(dayOffset)
                if !includeBacklog && day < 0 { return nil }
                guard day < maxDay else { return nil }
                return (day: day, count: Int(count))
            }
            .sorted(by: { $0.day < $1.day })
    }

    private func totalDue(_ data: [(day: Int, count: Int)]) -> Int {
        data.reduce(0) { $0 + $1.count }
    }

    private func dueTomorrow(_ data: [(day: Int, count: Int)]) -> Int {
        data.first(where: { $0.day == 1 })?.count ?? 0
    }

    private func avgPerDay(_ data: [(day: Int, count: Int)]) -> Double {
        let positiveDays = data.filter { $0.day >= 0 }
        guard !positiveDays.isEmpty else { return 0 }
        let maxOffset = positiveDays.map(\.day).max() ?? 1
        return Double(positiveDays.reduce(0) { $0 + $1.count }) / Double(max(maxOffset, 1))
    }

    public var body: some View {
        let filteredData = self.filteredData
        AmgiCard(
            background: .surface,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Future Due").amgiFont(.bodyEmphasis)

                if filteredData.isEmpty {
                    Text("No cards due").foregroundStyle(palette.textSecondary).frame(height: cappedChartHeight)
                } else {
                    Chart(filteredData, id: \.day) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Cards", item.count)
                        )
                        .foregroundStyle(item.day < 0 ? palette.danger.gradient : palette.accent.gradient)
                        .accessibilityLabel(
                            item.day < 0
                                ? "\(ChartSpeech.day(item.day)), overdue"
                                : ChartSpeech.day(item.day)
                        )
                        .accessibilityValue(ChartSpeech.count(item.count, "card"))
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel(collisionResolution: .greedy)
                        }
                    }
                    .frame(height: cappedChartHeight)
                }

                if futureDue.haveBacklog {
                    Toggle("Include Backlog", isOn: $includeBacklog)
                        .amgiFont(.caption)
                }

                let items = [
                    (label: "Total", value: "\(totalDue(filteredData))"),
                    (label: "Avg/day", value: String(format: "%.1f", avgPerDay(filteredData))),
                    (label: "Tomorrow", value: "\(dueTomorrow(filteredData))"),
                    (label: "Daily Load", value: "\(futureDue.dailyLoad)"),
                ]
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AmgiSpacing.lg) {
                        ForEach(items, id: \.label) { footerItem($0.label, value: $0.value) }
                    }
                    Grid(horizontalSpacing: AmgiSpacing.lg, verticalSpacing: AmgiSpacing.sm) {
                        GridRow {
                            footerItem(items[0].label, value: items[0].value)
                            footerItem(items[1].label, value: items[1].value)
                        }
                        GridRow {
                            footerItem(items[2].label, value: items[2].value)
                            footerItem(items[3].label, value: items[3].value)
                        }
                    }
                    VStack(spacing: AmgiSpacing.sm) {
                        ForEach(items, id: \.label) { footerItem($0.label, value: $0.value) }
                    }
                }
            }
        }
    }
}

private extension FutureDueChart {
    func footerItem(_ label: String, value: String) -> some View {
        VStack(spacing: AmgiSpacing.xxs) {
            Text(value).amgiFont(.captionBold).monospacedDigit()
            Text(label).amgiFont(.micro).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    FutureDueChart(futureDue: .sample, period: .month)
        .padding()
}
#endif
