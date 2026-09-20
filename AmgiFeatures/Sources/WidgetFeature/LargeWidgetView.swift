//
//  LargeWidgetView.swift
//  WidgetFeature
//
//  Created by Vladimir Gusev on 07.04.2026.
//

import Foundation
import SwiftUI
import WidgetKit
import Theme
import AppCore

struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: AmgiSpacing.md) {
            DeckHeader(deckName: snapshot.deckName, streak: snapshot.streak)
            DueHero(totalDue: snapshot.totalDue, axis: .horizontal)
            TodayProgress(reviewedToday: snapshot.reviewedToday, totalDue: snapshot.totalDue)
            WidgetSeparator()
            CountBreakdown(
                newCount: snapshot.newCount,
                learnCount: snapshot.learnCount,
                reviewCount: snapshot.reviewCount
            )
            WidgetSeparator()
            WeekChart(counts: snapshot.lastSevenDays, endingOn: snapshot.snapshotDate)
        }
        .padding(AmgiSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "amgi://review?deckId=\(snapshot.deckId)"))
    }
}

// MARK: - Sections

private struct DeckHeader: View {
    @Environment(\.palette) private var palette
    let deckName: String
    let streak: Int

    var body: some View {
        HStack {
            Text(deckName)
                .amgiFont(.captionBold)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            StreakLabel(days: streak)
        }
    }
}

private struct TodayProgress: View {
    @Environment(\.palette) private var palette
    let reviewedToday: Int
    let totalDue: Int

    private var fraction: Double {
        let total = reviewedToday + totalDue
        guard total > 0 else { return 0 }
        return min(1.0, Double(reviewedToday) / Double(total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AmgiSpacing.xs) {
            Gauge(value: fraction) { EmptyView() }
                .gaugeStyle(.linearCapacity)
                .tint(palette.accent)
                .accessibilityHidden(true)
            Text("\(reviewedToday) reviewed today · \(totalDue) remaining")
                .amgiFont(.micro, .monospacedDigits)
                .foregroundStyle(palette.textTertiary)
        }
    }
}

private struct WidgetSeparator: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle()
            .fill(palette.separator)
            .frame(height: 1)
    }
}

private struct CountBreakdown: View {
    @Environment(\.palette) private var palette
    let newCount: Int
    let learnCount: Int
    let reviewCount: Int

    var body: some View {
        HStack(spacing: 0) {
            column(color: palette.cardStateNew, label: "New", count: newCount)
            column(color: palette.cardStateLearning, label: "Learn", count: learnCount)
            column(color: palette.cardStateReview, label: "Review", count: reviewCount)
        }
        .frame(maxWidth: .infinity)
    }

    private func column(color: Color, label: String, count: Int) -> some View {
        VStack(spacing: AmgiSpacing.xxs) {
            Text("\(count)")
                .amgiFont(size: 22, weight: .semibold, tracking: -0.3, relativeTo: .title2)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .amgiFont(.micro)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct WeekChart: View {
    @Environment(\.palette) private var palette
    /// Oldest first; the last element is the day `endingOn` falls in.
    let counts: [Int]
    let endingOn: Date

    private var chartMax: Int { counts.max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: AmgiSpacing.sm) {
            // Cased in the literal, not via `.textCase(.uppercase)`, so a
            // translation can choose its own casing.
            Text("LAST 7 DAYS")
                .amgiFont(size: 11, weight: .medium, tracking: 1.5, relativeTo: .caption2)
                .foregroundStyle(palette.textTertiary)

            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: AmgiSpacing.xs) {
                    ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                        bar(count: count, isToday: index == counts.count - 1, in: geo.size.height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }

            HStack(spacing: AmgiSpacing.xs) {
                ForEach(counts.indices, id: \.self) { index in
                    Text(dayLabel(index))
                        .amgiFont(.micro)
                        .foregroundStyle(
                            index == counts.count - 1 ? palette.textSecondary : palette.textTertiary
                        )
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reviews in the last 7 days")
        .accessibilityValue(
            counts.enumerated()
                .map { "\(dayLabel($0.offset)) \($0.element)" }
                .formatted(.list(type: .and))
        )
    }

    private func bar(count: Int, isToday: Bool, in available: CGFloat) -> some View {
        let fraction = chartMax > 0 ? CGFloat(count) / CGFloat(chartMax) : 0
        return RoundedRectangle(cornerRadius: AmgiRadius.small / 2, style: .continuous)
            .fill(palette.accent.opacity(count == 0 ? 0.2 : (isToday ? 1 : 0.55)))
            .frame(maxWidth: .infinity)
            .frame(height: count == 0 ? 2 : max(4, available * fraction))
    }

    private func dayLabel(_ index: Int) -> String {
        let calendar = Calendar.current
        let offset = index - (counts.count - 1)
        let day = calendar.date(byAdding: .day, value: offset, to: endingOn) ?? endingOn
        return calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
    }
}

#if DEBUG

// See the note on SmallWidgetView's preview for why this uses a hand-set frame
// instead of any WidgetKit preview API.
#Preview {
    WidgetPreviewFrame(width: 364, height: 382) {
        LargeWidgetView(snapshot: .placeholder)
    }
}
#endif
