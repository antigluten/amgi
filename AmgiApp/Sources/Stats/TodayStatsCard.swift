import SwiftUI
import AnkiProto

struct PeriodStatsCard: View {
    let period: StatsPeriod
    let today: Anki_Stats_GraphsResponse.Today
    let reviews: Anki_Stats_GraphsResponse.ReviewCountsAndTimes

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
        VStack(alignment: .leading, spacing: 12) {
            Text(periodTitle)
                .amgiFont(.captionBold)
                .foregroundStyle(Color.amgiTextSecondary)
                .textCase(.uppercase)

            if period == .day {
                HStack {
                    statItem(title: "Reviewed", value: "\(today.answerCount)", color: .primary)
                    Spacer()
                    statItem(title: "Time", value: formatMillis(UInt64(today.answerMillis)), color: .primary)
                    Spacer()
                    statItem(title: "Correct", value: todayAccuracy, color: .green)
                    Spacer()
                    statItem(title: "Mature%", value: todayMatureAccuracy, color: .purple)
                }
                Divider()
                HStack {
                    statBadge("New", count: today.learnCount, color: .cyan)
                    Spacer()
                    statBadge("Relearn", count: today.relearnCount, color: .orange)
                    Spacer()
                    statBadge("Review", count: today.reviewCount, color: .green)
                    Spacer()
                    statBadge("Again", count: today.answerCount - today.correctCount, color: .red)
                }
            } else {
                let agg = aggregated
                HStack {
                    statItem(title: "Reviewed", value: "\(agg.total)", color: .primary)
                    Spacer()
                    statItem(title: "Time", value: formatMillis(agg.timeMillis), color: .primary)
                    Spacer()
                    statItem(title: "Young", value: "\(agg.young)", color: .green)
                    Spacer()
                    statItem(title: "Mature", value: "\(agg.mature)", color: .purple)
                }
                Divider()
                HStack {
                    statBadge("New", count: UInt32(agg.learn), color: .cyan)
                    Spacer()
                    statBadge("Relearn", count: UInt32(agg.relearn), color: .orange)
                    Spacer()
                    statBadge("Young", count: UInt32(agg.young), color: .green)
                    Spacer()
                    statBadge("Mature", count: UInt32(agg.mature), color: .purple)
                }
            }
        }
        .amgiCard(elevated: true)
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: AmgiSpacing.xxs) {
            Text(value).amgiFont(.sectionHeading).foregroundStyle(color)
            Text(title).amgiFont(.caption).foregroundStyle(Color.amgiTextSecondary)
        }
    }

    private func statBadge(_ title: String, count: UInt32, color: Color) -> some View {
        VStack(spacing: AmgiSpacing.xxs) {
            Text("\(count)").amgiFont(.bodyEmphasis).foregroundStyle(color)
            Text(title).amgiFont(.micro).foregroundStyle(Color.amgiTextSecondary)
        }
    }

    private func formatMillis(_ ms: UInt64) -> String {
        let seconds = ms / 1000
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
