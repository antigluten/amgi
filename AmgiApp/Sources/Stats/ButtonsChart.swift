import SwiftUI
import AmgiTheme
import AmgiUI
import Charts
import AnkiKit

struct ButtonsChart: View {
    let buttons: ButtonsBuckets
    let period: StatsPeriod

    @Environment(\.palette) private var palette

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
        AmgiCard(
            background: .surface,
            shadow: palette.shadows.sm,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Answer Buttons").amgiFont(.bodyEmphasis)

                if entries.isEmpty {
                    Text("No button data").foregroundStyle(palette.textSecondary).frame(height: 180)
                } else {
                    Chart(entries) { entry in
                        BarMark(
                            x: .value("Button", entry.button),
                            y: .value("Count", entry.count)
                        )
                        .foregroundStyle(by: .value("Type", entry.cardType))
                    }
                    .chartForegroundStyleScale([
                        "Learning": palette.cardStateNew,
                        "Young": palette.cardStateLearning,
                        "Mature": palette.cardStateMature,
                    ])
                    .frame(height: 180)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ButtonsChart(buttons: .sample, period: .month)
        .padding()
}
