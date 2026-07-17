import SwiftUI
import AmgiTheme
import AmgiUI
import AnkiKit

struct PeriodStatsCard: View {
    let period: StatsPeriod
    let today: TodayCounts
    let reviews: ReviewCountsAndTimes
    @Environment(\.palette) private var palette

    private var periodTitle: String {
        switch period {
        case .day: return "Today"
        case .week: return "Last 7 Days"
        case .month: return "Last Month"
        case .threeMonths: return "Last 3 Months"
        case .year: return "Last Year"
        case .all: return "All Time"
        }
    }

    private struct Aggregated {
        var total: Int = 0
        var timeMillis: UInt64 = 0
        var learn: Int = 0
        var relearn: Int = 0
        var young: Int = 0
        var mature: Int = 0
    }

    private var aggregated: Aggregated {
        var agg = Aggregated()
        let limit = period.days
        for (dayOffset, rev) in reviews.count {
            let day = Int(dayOffset)
            guard day <= 0, abs(day) < limit else { continue }
            agg.learn += Int(rev.learn)
            agg.relearn += Int(rev.relearn)
            agg.young += Int(rev.young)
            agg.mature += Int(rev.mature)
        }
        for (dayOffset, t) in reviews.time {
            let day = Int(dayOffset)
            guard day <= 0, abs(day) < limit else { continue }
            agg.timeMillis += UInt64(t.learn) + UInt64(t.relearn) + UInt64(t.young) + UInt64(t.mature) + UInt64(t.filtered)
        }
        agg.total = agg.learn + agg.relearn + agg.young + agg.mature
        return agg
    }

    private var todayAccuracy: String {
        guard today.answerCount > 0 else { return "---" }
        let pct = Int(Double(today.correctCount) / Double(today.answerCount) * 100)
        return "\(pct)%"
    }

    private var todayMatureAccuracy: String {
        guard today.matureCount > 0 else { return "---" }
        let pct = Int(Double(today.matureCorrect) / Double(today.matureCount) * 100)
        return "\(pct)%"
    }

    var body: some View {
        AmgiCard(
            background: .surfaceElevated,
            shadow: palette.shadows.md,
            cornerRadius: AmgiRadius.inset,
            contentInsets: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            statsContent
        }
    }

    @ViewBuilder
    private var statsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(periodTitle)
                .amgiFont(.captionBold)
                .foregroundStyle(palette.textSecondary)
                .textCase(.uppercase)

            if period == .day {
                HStack {
                    statItem(title: "Reviewed", value: "\(today.answerCount)", color: palette.textPrimary)
                    Spacer()
                    statItem(title: "Time", value: formatMillis(UInt64(today.answerMillis)), color: palette.textPrimary)
                    Spacer()
                    statItem(title: "Correct", value: todayAccuracy, color: palette.positive)
                    Spacer()
                    statItem(title: "Mature%", value: todayMatureAccuracy, color: palette.cardStateMature)
                }
                Divider()
                HStack {
                    statBadge("New", count: today.learnCount, color: palette.cardStateNew)
                    Spacer()
                    statBadge("Relearn", count: today.relearnCount, color: palette.cardStateRelearn)
                    Spacer()
                    statBadge("Review", count: today.reviewCount, color: palette.cardStateLearning)
                    Spacer()
                    statBadge("Again", count: today.answerCount - today.correctCount, color: palette.danger)
                }
            } else {
                let agg = aggregated
                HStack {
                    statItem(title: "Reviewed", value: "\(agg.total)", color: palette.textPrimary)
                    Spacer()
                    statItem(title: "Time", value: formatMillis(agg.timeMillis), color: palette.textPrimary)
                    Spacer()
                    statItem(title: "Young", value: "\(agg.young)", color: palette.cardStateLearning)
                    Spacer()
                    statItem(title: "Mature", value: "\(agg.mature)", color: palette.cardStateMature)
                }
                Divider()
                HStack {
                    statBadge("New", count: agg.learn, color: palette.cardStateNew)
                    Spacer()
                    statBadge("Relearn", count: agg.relearn, color: palette.cardStateRelearn)
                    Spacer()
                    statBadge("Young", count: agg.young, color: palette.cardStateLearning)
                    Spacer()
                    statBadge("Mature", count: agg.mature, color: palette.cardStateMature)
                }
            }
        }
    }
}

private extension PeriodStatsCard {
    func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: AmgiSpacing.xxs) {
            Text(value).amgiFont(.sectionHeading).foregroundStyle(color)
            Text(title).amgiFont(.caption).foregroundStyle(palette.textSecondary)
        }
    }

    func statBadge(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: AmgiSpacing.xxs) {
            Text("\(count)").amgiFont(.bodyEmphasis).foregroundStyle(color)
            Text(title).amgiFont(.micro).foregroundStyle(palette.textSecondary)
        }
    }

    func formatMillis(_ ms: UInt64) -> String {
        let seconds = ms / 1000
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Preview

#Preview("Today") {
    PeriodStatsCard(period: .day, today: .sample, reviews: .sampleYear)
        .padding()
}

#Preview("Last Month") {
    PeriodStatsCard(period: .month, today: .sample, reviews: .sampleYear)
        .padding()
}
