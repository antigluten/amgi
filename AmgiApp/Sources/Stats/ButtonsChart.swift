import SwiftUI
import Charts
import AnkiKit

struct ButtonsChart: View {
    let buttons: ButtonsBuckets
    let period: StatsPeriod

    private var buttonCounts: ButtonsBuckets.ButtonCounts {
        switch period {
        case .day, .week, .month: buttons.oneMonth
        case .threeMonths: buttons.threeMonths
        case .year: buttons.oneYear
        case .all: buttons.allTime
        }
    }

    private struct ButtonEntry: Identifiable {
        let id = UUID()
        let button: String
        let cardType: String
        let count: Int
    }

    private let buttonLabels = ["Again", "Hard", "Good", "Easy"]
    private let cardTypes = ["Learning", "Young", "Mature"]

    private var entries: [ButtonEntry] {
        let bc = buttonCounts
        let sources: [(String, [Int])] = [
            ("Learning", bc.learning),
            ("Young", bc.young),
            ("Mature", bc.mature),
        ]
        var result: [ButtonEntry] = []
        for (typeName, counts) in sources {
            for (index, count) in counts.prefix(4).enumerated() {
                if count > 0 {
                    result.append(ButtonEntry(
                        button: buttonLabels[index],
                        cardType: typeName,
                        count: count
                    ))
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Answer Buttons").amgiFont(.bodyEmphasis)

            if entries.isEmpty {
                Text("No button data").foregroundStyle(.secondary).frame(height: 180)
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Button", entry.button),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(by: .value("Type", entry.cardType))
                }
                .chartForegroundStyleScale([
                    "Learning": Color.blue,
                    "Young": Color.green,
                    "Mature": Color.purple,
                ])
                .frame(height: 180)
            }
        }
        .amgiCard()
    }
}

// MARK: - Preview

#Preview {
    ButtonsChart(buttons: .sample, period: .month)
        .padding()
}
