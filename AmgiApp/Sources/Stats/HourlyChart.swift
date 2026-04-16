import SwiftUI
import Charts
import AnkiProto

struct HourlyChart: View {
    let hours: Anki_Stats_GraphsResponse.Hours
    let period: StatsPeriod

    private var hourData: [Anki_Stats_GraphsResponse.Hours.Hour] {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Breakdown").amgiFont(.bodyEmphasis)

            if entries.allSatisfy({ $0.total == 0 }) {
                Text("No review data").foregroundStyle(.secondary).frame(height: 180)
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Hour", entry.hour),
                        y: .value("Reviews", entry.total)
                    )
                    .foregroundStyle(.purple.gradient)
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
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Hour", entry.hour),
                        y: .value("Correct %", entry.correctPct)
                    )
                    .foregroundStyle(.green.opacity(0.1))
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
        .amgiCard()
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
}
