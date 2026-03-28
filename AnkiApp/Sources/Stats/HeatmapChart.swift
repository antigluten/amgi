import SwiftUI
import AnkiKit

struct HeatmapChart: View {
    let data: [DayCount]

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let weekdayLabelWidth: CGFloat = 22

    private var maxCount: Int { data.map(\.count).max() ?? 1 }

    private var countMap: [String: Int] {
        Dictionary(data.map { ($0.date, $0.count) }, uniquingKeysWith: { $1 })
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Computed Stats

    private var totalReviews: Int {
        data.reduce(0) { $0 + $1.count }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        // If no reviews today, start from yesterday
        if countMap[dateFormatter.string(from: day)] == nil || countMap[dateFormatter.string(from: day)] == 0 {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        while let count = countMap[dateFormatter.string(from: day)], count > 0 {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    private var reviewsThisWeek: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // Monday = start of week (weekday 2 in US locale)
        let daysFromMonday = (weekday + 5) % 7
        var total = 0
        for i in 0...daysFromMonday {
            let day = calendar.date(byAdding: .day, value: -i, to: today)!
            total += countMap[dateFormatter.string(from: day)] ?? 0
        }
        return total
    }

    private var reviewsThisMonth: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.component(.day, from: today)
        var total = 0
        for i in 0..<day {
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            total += countMap[dateFormatter.string(from: d)] ?? 0
        }
        return total
    }

    // MARK: - Grid Data (full year, 52 weeks)

    private var weeks: [[Date]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .weekOfYear, value: -51, to: today)!
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startDate)
        )!

        var result: [[Date]] = []
        var current = startOfWeek
        while current <= today {
            var week: [Date] = []
            for dayOffset in 0..<7 {
                week.append(calendar.date(byAdding: .day, value: dayOffset, to: current)!)
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
            let month = Calendar.current.component(.month, from: week[0])
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
            // Header with title and streak
            HStack {
                Text("Review Activity")
                    .font(.headline)
                Spacer()
                if currentStreak > 0 {
                    Label("\(currentStreak) day streak", systemImage: "flame.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            if data.isEmpty {
                Text("No review history yet")
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            } else {
                // Summary row
                HStack(spacing: 16) {
                    summaryItem(value: "\(totalReviews)", label: "Total")
                    summaryItem(value: "\(reviewsThisMonth)", label: "This Month")
                    summaryItem(value: "\(reviewsThisWeek)", label: "This Week")
                    summaryItem(
                        value: "\(countMap[dateFormatter.string(from: Date())] ?? 0)",
                        label: "Today"
                    )
                }

                // Scrollable heatmap
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Month labels
                        HStack(spacing: 0) {
                            Spacer().frame(width: weekdayLabelWidth)
                            ForEach(0..<weeks.count, id: \.self) { weekIdx in
                                if let label = monthLabels.first(where: { $0.1 == weekIdx }) {
                                    Text(label.0)
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                        .frame(width: cellSize + cellSpacing, alignment: .leading)
                                } else {
                                    Spacer().frame(width: cellSize + cellSpacing)
                                }
                            }
                        }
                        .frame(height: 14)

                        // Grid: weekday labels + cells
                        HStack(alignment: .top, spacing: 0) {
                            // Weekday labels
                            VStack(spacing: cellSpacing) {
                                ForEach(0..<7, id: \.self) { day in
                                    Text(weekdayLabel(day))
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .frame(width: weekdayLabelWidth, height: cellSize)
                                }
                            }

                            // Heatmap cells
                            HStack(spacing: cellSpacing) {
                                ForEach(0..<weeks.count, id: \.self) { weekIdx in
                                    VStack(spacing: cellSpacing) {
                                        ForEach(0..<7, id: \.self) { dayIdx in
                                            let date = weeks[weekIdx][dayIdx]
                                            let count = countMap[dateFormatter.string(from: date)] ?? 0
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
                .defaultScrollAnchor(.trailing) // Start scrolled to the right (today)

                // Legend
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
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
        case 0: return ""
        case 1: return "M"
        case 2: return ""
        case 3: return "W"
        case 4: return ""
        case 5: return "F"
        case 6: return ""
        default: return ""
        }
    }

    private func heatColor(count: Int) -> Color {
        if count == 0 { return Color(.systemGray6) }
        let intensity = min(1.0, Double(count) / Double(max(maxCount, 1)))
        return .green.opacity(max(0.2, intensity))
    }
}
