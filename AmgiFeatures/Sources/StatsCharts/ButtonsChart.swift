//
//  ButtonsChart.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 30.03.2026.
//

public import SwiftUI
import Theme
import UI
import Charts
public import AnkiKit

public struct ButtonsChart: View {
    let buttons: ButtonsBuckets
    let period: StatsPeriod

    public init(buttons: ButtonsBuckets, period: StatsPeriod) {
        self.buttons = buttons
        self.period = period
    }

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
        /// Stable across rebuilds — Charts diffs marks by `id`, and a fresh
        /// `UUID` would re-identify every bar on every `body` pass.
        var id: String { "\(cardType)-\(button)" }
        let button: String
        let cardType: String
        let count: Int
    }

    private let buttonLabels = [String(localized: "Again", bundle: .module), String(localized: "Hard", bundle: .module), String(localized: "Good", bundle: .module), String(localized: "Easy", bundle: .module)]
    private let cardTypes = [String(localized: "Learning", bundle: .module), String(localized: "Young", bundle: .module), String(localized: "Mature", bundle: .module)]

    private var entries: [ButtonEntry] {
        let bc = buttonCounts
        let sources: [(String, [Int])] = [
            (String(localized: "Learning", bundle: .module), bc.learning),
            (String(localized: "Young", bundle: .module), bc.young),
            (String(localized: "Mature", bundle: .module), bc.mature),
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

    public var body: some View {
        let entries = self.entries
        AmgiCard(
            background: .surface,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Answer Buttons", bundle: .module).amgiFont(.bodyEmphasis)

                if entries.isEmpty {
                    Text("No button data", bundle: .module).foregroundStyle(palette.textSecondary).frame(height: 180)
                } else {
                    Chart(entries) { entry in
                        BarMark(
                            x: .value(String(localized: "Button", bundle: .module), entry.button),
                            y: .value(String(localized: "Count", bundle: .module), entry.count)
                        )
                        .foregroundStyle(by: .value(String(localized: "Type", bundle: .module), entry.cardType))
                        .accessibilityLabel("\(entry.cardType), \(entry.button)")
                        .accessibilityValue(ChartSpeech.count(entry.count, .press))
                    }
                    .chartForegroundStyleScale([
                        String(localized: "Learning", bundle: .module): palette.cardStateNew,
                        String(localized: "Young", bundle: .module): palette.cardStateLearning,
                        String(localized: "Mature", bundle: .module): palette.cardStateMature,
                    ])
                    .frame(height: 180)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ButtonsChart(buttons: .sample, period: .month)
        .padding()
}
#endif
