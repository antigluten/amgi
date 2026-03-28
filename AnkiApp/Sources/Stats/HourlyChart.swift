import SwiftUI
import Charts
import AnkiKit

struct HourlyChart: View {
    let data: [HourCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Study Hours").font(.headline)

            if data.isEmpty {
                Text("No review history yet").foregroundStyle(.secondary).frame(height: 150)
            } else {
                Chart(allHours, id: \.hour) { item in
                    BarMark(
                        x: .value("Hour", formatHour(item.hour)),
                        y: .value("Reviews", item.count)
                    )
                    .foregroundStyle(.purple.gradient)
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var allHours: [HourCount] {
        let hourMap = Dictionary(uniqueKeysWithValues: data.map { ($0.hour, $0.count) })
        return (0..<24).map { hour in
            HourCount(hour: hour, count: hourMap[hour] ?? 0)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
}
