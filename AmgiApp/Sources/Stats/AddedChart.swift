import SwiftUI
import Charts
import AnkiProto

struct AddedChart: View {
    let added: Anki_Stats_GraphsResponse.Added
    let period: StatsPeriod

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
        VStack(alignment: .leading, spacing: 8) {
            Text("Cards Added").amgiFont(.bodyEmphasis)

            if filteredData.isEmpty {
                Text("No cards added").foregroundStyle(.secondary).frame(height: 180)
            } else {
                Chart(filteredData, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Cards", item.count)
                    )
                    .foregroundStyle(.cyan.gradient)
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
            .font(.caption2)
        }
        .amgiCard()
    }

    private func footerItem(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
            Text(label).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
