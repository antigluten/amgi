import SwiftUI
import Charts
import AnkiKit

struct ForecastChart: View {
    let data: [DayCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Forecast (30 days)").amgiFont(.bodyEmphasis)

            if data.isEmpty || data.allSatisfy({ $0.count == 0 }) {
                Text("Review some cards to see forecast")
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
            } else {
                Chart(data, id: \.date) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Cards", item.count)
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .frame(height: 180)
            }
        }
        .amgiCard()
    }
}
