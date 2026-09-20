//
//  StreakCard.swift
//  StatsCharts
//
//  Created by Vladimir Gusev on 18.09.2026.
//

public import SwiftUI
import Theme
import UI

public struct StreakCard: View {
    private let streak: Int
    private let comparison: Int?

    public init(streak: Int, comparison: Int?) {
        self.streak = streak
        self.comparison = comparison
    }

    @Environment(\.palette) private var palette

    public var body: some View {
        AmgiCard(
            background: .surface,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            HStack(spacing: AmgiSpacing.lg) {
                flameDisc
                VStack(alignment: .leading, spacing: AmgiSpacing.xxs) {
                    Text("Streak")
                        .amgiFont(.captionBold)
                        .foregroundStyle(palette.textSecondary)
                        .textCase(.uppercase)
                    Text(streakLabel)
                        .amgiFont(.displayHero)
                        .foregroundStyle(palette.textPrimary)
                    if let comparisonLabel {
                        Text(comparisonLabel)
                            .amgiFont(.caption)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Review streak")
            .accessibilityValue(accessibilityValue)
        }
    }

    private var flameDisc: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [palette.cardStateRelearn, palette.cardStateLearning],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .amgiFont(.sectionHeading)
                    .foregroundStyle(palette.surfaceElevated)
            }
            .opacity(streak > 0 ? 1 : 0.4)
            .accessibilityHidden(true)
    }

    private var streakLabel: String {
        switch streak {
        case 0: "No streak"
        case 1: "1 day"
        default: "\(streak) days"
        }
    }

    private var comparisonLabel: String? {
        guard let comparison else { return nil }
        guard streak > 0 || comparison != 0 else {
            return "Review today to start one"
        }
        return switch comparison {
        case 1: "1 day ahead of last month"
        case let n where n > 1: "\(n) days ahead of last month"
        case -1: "1 day behind last month"
        case let n where n < -1: "\(-n) days behind last month"
        default: "Level with last month"
        }
    }

    private var accessibilityValue: String {
        guard let comparisonLabel else { return streakLabel }
        return "\(streakLabel), \(comparisonLabel)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Ahead") {
    StreakCard(streak: 36, comparison: 4).padding()
}

#Preview("Behind") {
    StreakCard(streak: 2, comparison: -7).padding()
}

#Preview("No streak") {
    StreakCard(streak: 0, comparison: 0).padding()
}

#Preview("Loading comparison") {
    StreakCard(streak: 12, comparison: nil).padding()
}
#endif
