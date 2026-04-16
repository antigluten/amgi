import SwiftUI
import Charts
import AnkiProto

struct ReviewsChart: View {
    let reviews: Anki_Stats_GraphsResponse.ReviewCountsAndTimes
    let period: StatsPeriod

    private struct ReviewEntry: Identifiable {
        let id = UUID()
        let day: Int
        let type: String
        let count: Int
        let color: Color
    }

    private var entries: [ReviewEntry] {
        let maxDay = period.days
        let types: [(String, KeyPath<Anki_Stats_GraphsResponse.ReviewCountsAndTimes.Reviews, UInt32>, Color)] = [
            ("Learn", \.learn, .blue),
            ("Relearn", \.relearn, .orange),
            ("Young", \.young, .green),
            ("Mature", \.mature, .purple),
            ("Filtered", \.filtered, .gray),
        ]
        var result: [ReviewEntry] = []
        for (dayOffset, rev) in reviews.count {
            let day = Int(dayOffset)
            guard day <= 0, abs(day) <= maxDay else { continue }
            for (name, kp, color) in types {
                let value = Int(rev[keyPath: kp])
                if value > 0 {
                    result.append(ReviewEntry(day: day, type: name, count: value, color: color))
                }
            }
        }
        return result.sorted(by: { $0.day < $1.day })
    }

    private var totalReviews: Int {
        entries.reduce(0) { $0 + $1.count }
    }

    private var avgPerDay: Double {
        guard !entries.isEmpty else { return 0 }
        let uniqueDays = Set(entries.map(\.day)).count
        return Double(totalReviews) / Double(max(uniqueDays, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reviews").amgiFont(.bodyEmphasis)

            if entries.isEmpty {
                Text("No review data").foregroundStyle(.secondary).frame(height: 180)
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Day", entry.day),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(by: .value("Type", entry.type))
                }
                .chartForegroundStyleScale([
                    "Learn": Color.blue,
                    "Relearn": Color.orange,
                    "Young": Color.green,
                    "Mature": Color.purple,
                    "Filtered": Color.gray,
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
                footerItem("Total", value: "\(totalReviews)")
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
