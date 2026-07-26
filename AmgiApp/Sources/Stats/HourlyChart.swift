import SwiftUI
import AmgiTheme
import AmgiUI
import Charts
import AnkiKit

struct HourlyChart: View {
    let hours: HoursBuckets
    let period: StatsPeriod

    @Environment(\.palette) private var palette

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

    var body: some View {
        AmgiCard(
            background: .surface,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hourly Breakdown").amgiFont(.bodyEmphasis)

                if entries.allSatisfy({ $0.total == 0 }) {
                    Text("No review data").foregroundStyle(palette.textSecondary).frame(height: 180)
                } else {
                    Chart(entries) { entry in
                        BarMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Reviews", entry.total)
                        )
                        .foregroundStyle(palette.accent.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 4, 8, 12, 16, 20]) { value in
                            AxisGridLine()
                            if let h = value.as(Int.self) {
                                AxisValueLabel(formatHour(h))
                            }
                        }
                    }
                    .chartXScale(domain: 0...23)
                    .frame(height: 150)

                    Chart(entries) { entry in
                        LineMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Correct %", entry.correctPct)
                        )
                        .foregroundStyle(palette.positive)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Correct %", entry.correctPct)
                        )
                        .foregroundStyle(palette.positive.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 4, 8, 12, 16, 20]) { value in
                            AxisGridLine()
                            if let h = value.as(Int.self) {
                                AxisValueLabel(formatHour(h))
                            }
                        }
                    }
                    .chartXScale(domain: 0...23)
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("Correct %")
                    .frame(height: 100)
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
