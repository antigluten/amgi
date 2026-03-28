import SwiftUI
import AnkiKit

struct TodayStatsCard: View {
    let stats: TodayStats

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                statItem(title: "Reviewed", value: "\(stats.reviewed)", color: .primary)
                Spacer()
                statItem(title: "Time", value: formatTime(stats.timeSpentMs), color: .primary)
                Spacer()
                statItem(
                    title: "Accuracy",
                    value: stats.reviewed > 0
                        ? "\(Int(Double(stats.reviewed - stats.againCount) / Double(stats.reviewed) * 100))%"
                        : "---",
                    color: .green
                )
            }
            Divider()
            HStack {
                statBadge("New", count: stats.newCards, color: .blue)
                Spacer()
                statBadge("Learning", count: stats.learnCards, color: .orange)
                Spacer()
                statBadge("Review", count: stats.reviewCards, color: .green)
                Spacer()
                statBadge("Again", count: stats.againCount, color: .red)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func statBadge(_ title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.subheadline.weight(.medium)).foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func formatTime(_ ms: Int) -> String {
        let seconds = ms / 1000
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
