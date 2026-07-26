import SwiftUI
import AmgiTheme
import AmgiUI
import Charts
import AnkiKit

struct AddedChart: View {
    let added: AddedSeries
    let period: StatsPeriod

    @Environment(\.palette) private var palette

    private var filteredData: [(day: Int, count: Int)] {
        let maxDay = period.days
        return added.added
            .compactMap { (dayOffset, count) -> (day: Int, count: Int)? in
                let day = Int(dayOffset)
                guard day <= 0, abs(day) <= maxDay else { return nil }
                return (day: day, count: Int(count))
            }
            .sorted(by: { $0.day < $1.day })
    }

    private var totalAdded: Int { filteredData.reduce(0) { $0 + $1.count } }
    private var avgPerDay: Double {
        guard !filteredData.isEmpty else { return 0 }
        let days = Set(filteredData.map(\.day)).count
        return Double(totalAdded) / Double(max(days, 1))
    }

    var body: some View {
        AmgiCard(
            background: .surface,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cards Added").amgiFont(.bodyEmphasis)

                if filteredData.isEmpty {
                    Text("No cards added").foregroundStyle(palette.textSecondary).frame(height: 180)
                } else {
                    Chart(filteredData, id: \.day) { item in
                        BarMark(
                            x: .value("Day", item.day),
                            y: .value("Cards", item.count)
                        )
                        .foregroundStyle(palette.accent.gradient)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 180)
                }

                HStack(spacing: 16) {
                    footerItem("Total", value: "\(totalAdded)")
                    footerItem("Avg/day", value: String(format: "%.1f", avgPerDay))
                }
            }
        }
    }
}

private extension AddedChart {
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
    AddedChart(added: .sample, period: .month)
        .padding()
}
#endif
