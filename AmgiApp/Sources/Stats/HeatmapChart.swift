import SwiftUI
import AnkiProto

struct HeatmapChart: View {
    let reviews: Anki_Stats_GraphsResponse.ReviewCountsAndTimes

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let weekdayLabelWidth: CGFloat = 22

    // MARK: - Day Count Map (dayOffset -> total reviews)

    private var dayCountMap: [Int: Int] {
        var map: [Int: Int] = [:]
        for (dayOffset, rev) in reviews.count {
            let total = Int(rev.learn + rev.relearn + rev.young + rev.mature + rev.filtered)
            if total > 0 {
                map[Int(dayOffset)] = total
            }
        }
        return map
    }

    private var maxCount: Int { dayCountMap.values.max() ?? 1 }

    // MARK: - Date Mapping

    private let calendar = Calendar.current

    private func dayOffset(for date: Date) -> Int {
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    // MARK: - Computed Stats

    private var totalReviews: Int {
        dayCountMap.values.reduce(0, +)
    }

    private var currentStreak: Int {
        var streak = 0
        var offset = 0
        // If no reviews today, start from yesterday
        if dayCountMap[0] == nil || dayCountMap[0] == 0 {
            offset = -1
        }
        while let count = dayCountMap[offset], count > 0 {
            streak += 1
            offset -= 1
        }
        return streak
    }

    private var reviewsThisWeek: Int {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        return (0...daysFromMonday).reduce(0) { $0 + (dayCountMap[-$1] ?? 0) }
    }

    private var reviewsThisMonth: Int {
        let day = calendar.component(.day, from: Date())
        return (0..<day).reduce(0) { $0 + (dayCountMap[-$1] ?? 0) }
    }

    // MARK: - Grid Data

    /// Number of weeks to show based on data range
    private var weeksToShow: Int {
        guard let minOffset = dayCountMap.keys.min() else { return 52 }
        let totalDays = abs(minOffset) + 7 // add a week buffer
        let weeksNeeded = totalDays / 7 + 1
        return max(weeksNeeded, 52) // at least 1 year
    }

    private var weeks: [[Date]] {
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .weekOfYear, value: -(weeksToShow - 1), to: today)!
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
        )!

        var result: [[Date]] = []
        var current = startOfWeek
        while current <= today {
            var week: [Date] = []
            for dayOff in 0..<7 {
                week.append(calendar.date(byAdding: .day, value: dayOff, to: current)!)
            }
            result.append(week)
            current = calendar.date(byAdding: .weekOfYear, value: 1, to: current)!
        }
        return result
    }

    private var monthLabels: [(String, Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        var labels: [(String, Int)] = []
        var lastMonth = -1
        for (weekIdx, week) in weeks.enumerated() {
            let month = calendar.component(.month, from: week[0])
            if month != lastMonth {
                labels.append((fmt.string(from: week[0]), weekIdx))
                lastMonth = month
            }
        }
        return labels
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Review Activity")
                    .amgiFont(.bodyEmphasis)
                Spacer()
                if currentStreak > 0 {
                    Label("\(currentStreak) day streak", systemImage: "flame.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            if dayCountMap.isEmpty {
                Text("No review history yet")
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            } else {
                HStack(spacing: 16) {
                    summaryItem(value: "\(totalReviews)", label: "Total")
                    summaryItem(value: "\(reviewsThisMonth)", label: "This Month")
                    summaryItem(value: "\(reviewsThisWeek)", label: "This Week")
                    summaryItem(value: "\(dayCountMap[0] ?? 0)", label: "Today")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer().frame(width: weekdayLabelWidth)
                            ForEach(0..<weeks.count, id: \.self) { weekIdx in
                                if let label = monthLabels.first(where: { $0.1 == weekIdx }) {
                                    Text(label.0)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                        .frame(width: cellSize + cellSpacing, alignment: .leading)
                                } else {
                                    Spacer().frame(width: cellSize + cellSpacing)
                                }
                            }
                        }
                        .frame(height: 14)

                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<7, id: \.self) { day in
                                    Text(weekdayLabel(day))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .frame(width: weekdayLabelWidth, height: cellSize)
                                }
                            }

                            HStack(spacing: cellSpacing) {
                                ForEach(0..<weeks.count, id: \.self) { weekIdx in
                                    VStack(spacing: cellSpacing) {
                                        ForEach(0..<7, id: \.self) { dayIdx in
                                            let date = weeks[weekIdx][dayIdx]
                                            let offset = dayOffset(for: date)
                                            let count = dayCountMap[offset] ?? 0
                                            let isFuture = date > Date()

                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(isFuture ? Color.clear : heatColor(count: count))
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .defaultScrollAnchor(.trailing)

                HStack(spacing: 4) {
                    Spacer()
                    Text("Less").font(.caption2).foregroundStyle(.secondary)
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green.opacity(max(0.1, intensity)))
                            .frame(width: cellSize, height: cellSize)
                    }
                    Text("More").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .amgiCard()
    }

    // MARK: - Helpers

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayLabel(_ index: Int) -> String {
        switch index {
        case 1: "M"
        case 3: "W"
        case 5: "F"
        default: ""
        }
    }

    private func heatColor(count: Int) -> Color {
        if count == 0 { return Color(.systemGray6) }
        let intensity = min(1.0, Double(count) / Double(max(maxCount, 1)))
        return .green.opacity(max(0.2, intensity))
    }
}
