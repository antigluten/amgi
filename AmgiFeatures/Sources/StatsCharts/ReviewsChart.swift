//
//  ReviewsChart.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 30.03.2026.
//

public import SwiftUI
import Theme
import UI
import Charts
public import AnkiKit

public struct ReviewsChart: View {
    let reviews: ReviewCountsAndTimes
    let period: StatsPeriod

    public init(reviews: ReviewCountsAndTimes, period: StatsPeriod) {
        self.reviews = reviews
        self.period = period
    }

    @Environment(\.palette) private var palette

    private struct ReviewEntry: Identifiable {
        static let typeCount = 5

        var id: Int { day * Self.typeCount + typeIndex }
        let day: Int
        let typeIndex: Int
        let type: String
        let count: Int
        let color: Color
    }

    private var entries: [ReviewEntry] {
        let maxDay = period.days
        let types: [(String, KeyPath<ReviewCountsAndTimes.Reviews, Int>, Color)] = [
            (String(localized: "Learn", bundle: .module), \.learn, palette.cardStateNew),
            (String(localized: "Relearn", bundle: .module), \.relearn, palette.cardStateRelearn),
            (String(localized: "Young", bundle: .module), \.young, palette.cardStateLearning),
            (String(localized: "Mature", bundle: .module), \.mature, palette.cardStateMature),
            (String(localized: "Filtered", bundle: .module), \.filtered, palette.textTertiary),
        ]
        var result: [ReviewEntry] = []
        for (day, rev) in reviews.count {
            guard day <= 0, abs(day) <= maxDay else { continue }
            for (typeIndex, (name, kp, color)) in types.enumerated() {
                let value = rev[keyPath: kp]
                if value > 0 {
                    result.append(ReviewEntry(
                        day: day, typeIndex: typeIndex,
                        type: name, count: value, color: color
                    ))
                }
            }
        }
        return result.sorted(by: { $0.day < $1.day })
    }

    private func totalReviews(_ entries: [ReviewEntry]) -> Int {
        entries.reduce(0) { $0 + $1.count }
    }

    private func avgPerDay(_ entries: [ReviewEntry]) -> Double {
        guard !entries.isEmpty else { return 0 }
        let uniqueDays = Set(entries.map(\.day)).count
        return Double(totalReviews(entries)) / Double(max(uniqueDays, 1))
    }

    public var body: some View {
        let entries = self.entries
        AmgiCard(
            background: .surface,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reviews", bundle: .module).amgiFont(.bodyEmphasis)

                if entries.isEmpty {
                    Text("No review data", bundle: .module).foregroundStyle(palette.textSecondary).frame(height: 180)
                } else {
                    Chart(entries) { entry in
                        BarMark(
                            x: .value(String(localized: "Day", bundle: .module), entry.day),
                            y: .value(String(localized: "Count", bundle: .module), entry.count)
                        )
                        .foregroundStyle(by: .value(String(localized: "Type", bundle: .module), entry.type))
                        .accessibilityLabel("\(entry.type), \(ChartSpeech.day(entry.day))")
                        .accessibilityValue(ChartSpeech.count(entry.count, .review))
                    }
                    .chartForegroundStyleScale([
                        String(localized: "Learn", bundle: .module): palette.cardStateNew,
                        String(localized: "Relearn", bundle: .module): palette.cardStateRelearn,
                        String(localized: "Young", bundle: .module): palette.cardStateLearning,
                        String(localized: "Mature", bundle: .module): palette.cardStateMature,
                        String(localized: "Filtered", bundle: .module): palette.textTertiary,
                    ])
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 180)
                }

                HStack(spacing: 16) {
                    footerItem(String(localized: "Total", bundle: .module), value: "\(totalReviews(entries))")
                    footerItem(String(localized: "Avg/day", bundle: .module), value: String(format: "%.1f", avgPerDay(entries)))
                }
            }
        }
    }
}

private extension ReviewsChart {
    func footerItem(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).amgiFont(.captionBold).monospacedDigit()
            Text(label).amgiFont(.caption).foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ReviewsChart(reviews: .sampleYear, period: .month)
        .padding()
}
#endif
