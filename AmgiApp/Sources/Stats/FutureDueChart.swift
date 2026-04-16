import SwiftUI
import Charts
import AnkiProto

struct FutureDueChart: View {
    let futureDue: Anki_Stats_GraphsResponse.FutureDue
    let period: StatsPeriod
    @State private var includeBacklog = false

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

    private var totalDue: Int { filteredData.reduce(0) { $0 + $1.count } }
    private var dueTomorrow: Int { filteredData.first(where: { $0.day == 1 })?.count ?? 0 }
    private var avgPerDay: Double {
        let positiveDays = filteredData.filter { $0.day >= 0 }
        guard !positiveDays.isEmpty else { return 0 }
        let maxOffset = positiveDays.map(\.day).max() ?? 1
        return Double(positiveDays.reduce(0) { $0 + $1.count }) / Double(max(maxOffset, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Future Due").amgiFont(.bodyEmphasis)

            if filteredData.isEmpty {
                Text("No cards due").foregroundStyle(.secondary).frame(height: 180)
            } else {
                Chart(filteredData, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Cards", item.count)
                    )
                    .foregroundStyle(item.day < 0 ? Color.red.gradient : Color.blue.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
            }

            if futureDue.haveBacklog {
                Toggle("Include Backlog", isOn: $includeBacklog)
                    .font(.caption)
            }

            HStack(spacing: 16) {
                footerItem("Total", value: "\(totalDue)")
                footerItem("Avg/day", value: String(format: "%.1f", avgPerDay))
                footerItem("Tomorrow", value: "\(dueTomorrow)")
                footerItem("Daily Load", value: "\(futureDue.dailyLoad)")
            }
        }
        .amgiCard()
    }

    private func footerItem(_ label: String, value: String) -> some View {
        VStack(spacing: AmgiSpacing.xxs) {
            Text(value).amgiFont(.captionBold).monospacedDigit()
            Text(label).amgiFont(.micro).foregroundStyle(Color.amgiTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
